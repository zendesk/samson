# frozen_string_literal: true
require 'soft_deletion'
require 'digest/md5'

class User < ActiveRecord::Base
  include Searchable
  include HasRole

  TIME_FORMATS = ['local', 'utc', 'relative'].freeze

  has_soft_deletion default_scope: true

  has_paper_trail skip: [:updated_at, :created_at, :token]

  has_many :commands
  has_many :stars
  has_many :locks, dependent: :destroy
  has_many :user_project_roles, dependent: :destroy
  has_many :projects, through: :user_project_roles
  has_many :csv_exports, dependent: :destroy

  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  before_create :set_token
  validates :time_format, inclusion: { in: TIME_FORMATS }
  validates :external_id, presence: :true, unless: :integration?

  scope :search, ->(query) {
    return self if query.blank?
    query = ActiveRecord::Base.send(:sanitize_sql_like, query)
    where("name LIKE ? OR email LIKE ?", "%#{query}%", "%#{query}%")
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
    attributes = user.attributes.merge(hash.stringify_keys) do |key, old, new|
      if key == 'role_id'
        if !User.exists? # first user will be the super admin
          Role::SUPER_ADMIN.id
        elsif new && (user.new_record? || new >= old)
          new
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

  def record_project_role_change
    record_update true
  end

  private

  # overwrites papertrail to record script
  def object_attrs_for_paper_trail(attributes)
    roles = user_project_roles.map { |upr| [upr.project.permalink, upr.role_id] }.to_h
    super(attributes.merge('project_roles' => roles))
  end

  def set_token
    self.token = SecureRandom.hex
  end
end
