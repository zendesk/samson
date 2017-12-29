# frozen_string_literal: true
require 'soft_deletion'
require 'digest/md5'

class User < ActiveRecord::Base
  include Searchable
  include HasRole

  TIME_FORMATS = ['local', 'utc', 'relative'].freeze

  has_soft_deletion default_scope: true

  audited except: [:last_seen_at, :last_login_at, :token]

  has_many :commands
  has_many :stars
  has_many :locks, dependent: :destroy
  has_many :user_project_roles, dependent: :destroy
  has_many :projects, through: :user_project_roles
  has_many :csv_exports, dependent: :destroy
  has_many :access_tokens, dependent: :destroy, class_name: 'Doorkeeper::AccessToken', foreign_key: :resource_owner_id

  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  before_create :set_token
  validates :time_format, inclusion: { in: TIME_FORMATS }
  validates :external_id,
    uniqueness: {scope: :deleted_at}, presence: true, unless: :integration?, if: :external_id_changed?

  before_soft_delete :destroy_user_project_roles

  scope :search, ->(query) {
    if query.blank?
      self
    else
      query = "%#{ActiveRecord::Base.send(:sanitize_sql_like, query)}%"
      where(User.arel_table[:name].matches(query).or(User.arel_table[:email].matches(query)))
    end
  }

  def self.with_role(role_id, project_id)
    if project_id.present?
      join_condition = "users.id = user_project_roles.user_id AND user_project_roles.project_id = #{project_id.to_i}"
      joins("LEFT OUTER JOIN user_project_roles ON #{join_condition}").
        where('users.role_id >= ? OR user_project_roles.role_id >= ?', role_id, role_id)
    else
      where('users.role_id >= ?', role_id)
    end
  end

  # @override Searchable
  def self.search_by_criteria(criteria)
    scope = super
    if role_id = criteria[:role_id].presence
      scope = scope.with_role(role_id, criteria[:project_id])
    end
    if email = criteria[:email].presence
      scope = scope.where(email: email)
    end
    if criteria.key?(:integration)
      value = criteria[:integration]
      if !value.nil? && value != ''
        value = !ActiveModel::Type::Boolean::FALSE_VALUES.include?(value)
        scope = scope.where(integration: value)
      end
    end
    scope
  end

  def starred_project?(project)
    starred_project_ids.include?(project.id)
  end

  def starred_project_ids
    Rails.cache.fetch([:starred_projects_ids, id]) do
      stars.pluck(:project_id)
    end
  end

  # returns a scope
  def administrated_projects
    scope = Project.order(:name)
    unless admin?
      allowed = user_project_roles.where(role_id: Role::ADMIN.id).pluck(:project_id)
      scope = scope.where(id: allowed)
    end
    scope
  end

  def self.create_or_update_from_hash(hash)
    user = User.where(external_id: hash[:external_id].to_s).first || User.new

    # attributes are always a string hash
    attributes = user.attributes.merge(hash.stringify_keys) do |attribute, old, new|
      if attribute == 'role_id'
        if !User.where.not(email: 'seed@example.com').exists?
          Role::SUPER_ADMIN.id # first user will be promoted to super admin
        elsif new && (user.new_record? || new >= old)
          new # existing users can upgrade
        else
          old
        end
      else
        old.presence || new
      end
    end

    user.attributes = attributes
    user.save
    user
  end

  def name
    super.presence || email
  end

  def name_and_email
    name == email ? name : "#{name} (#{email})"
  end

  def gravatar_url
    md5 = email.blank? ? "default" : Digest::MD5.hexdigest(email)
    "https://www.gravatar.com/avatar/#{md5}"
  end

  def admin_for?(project)
    admin? || !!project_role_for(project).try(:admin?)
  end

  def deployer_for?(project)
    deployer? || !!project_role_for(project).try(:deployer?)
  end

  def project_role_for(project)
    project && user_project_roles.find_by(project: project)
  end

  private

  def set_token
    self.token = SecureRandom.hex
  end

  def destroy_user_project_roles
    user_project_roles.each(&:destroy)
  end
end
