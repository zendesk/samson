# frozen_string_literal: true
require 'soft_deletion'
require 'digest/md5'

class User < ActiveRecord::Base
  include Searchable
  include HasRole

  TIME_FORMATS = ['local', 'utc', 'relative'].freeze
  GITHUB_USERNAME_REGEX = /\A[a-z\d](?:[a-z\d]|-(?=[a-z\d])){0,38}\Z/i.freeze

  has_soft_deletion default_scope: true
  include SoftDeleteWithDestroy

  audited except: [:last_seen_at, :last_login_at]

  has_many :stars, dependent: :destroy
  has_many :locks, dependent: :destroy
  has_many :user_project_roles, dependent: :destroy
  has_many :projects, through: :user_project_roles, inverse_of: :users
  has_many :csv_exports, dependent: :destroy
  has_many :builds, dependent: nil, foreign_key: :created_by, inverse_of: :creator
  has_many :jobs, dependent: nil, inverse_of: :user
  has_many :access_tokens,
    dependent: :destroy, class_name: 'Doorkeeper::AccessToken', foreign_key: :resource_owner_id, inverse_of: false

  validates :role_id, inclusion: {in: Role.all.map(&:id)}

  validates :time_format, inclusion: {in: TIME_FORMATS}
  validates :external_id,
    uniqueness: {scope: :deleted_at, case_sensitive: false},
    presence: true, unless: :integration?, if: :external_id_changed?
  validates :github_username, uniqueness: {case_sensitive: false}, format: GITHUB_USERNAME_REGEX, allow_blank: true

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
    if username = criteria[:github_username].presence
      scope = scope.where(github_username: username)
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
    admin? || !!project_role_for(project)&.admin?
  end

  def deployer_for?(project)
    deployer? || !!project_role_for(project)&.deployer?
  end

  def project_role_for(project)
    project && user_project_roles.find_by(project: project)
  end

  private

  def destroy_user_project_roles
    user_project_roles.each(&:destroy)
  end
end
Samson::Hooks.load_decorators(User)
