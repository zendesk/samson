require 'soft_deletion'
require 'digest/md5'

class User < ActiveRecord::Base
  include Searchable
  include HasRole

  TIME_FORMATS = ['local', 'utc', 'relative'].freeze

  has_soft_deletion default_scope: true

  has_many :commands
  has_many :stars
  has_many :locks, dependent: :destroy
  has_many :user_project_roles, dependent: :destroy
  has_many :projects, through: :user_project_roles

  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  before_create :set_token
  validates :time_format, inclusion: { in: TIME_FORMATS }

  scope :search, ->(query) { where("name like ? or email like ?", "%#{query}%", "%#{query}%") }

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
    unless is_admin?
      allowed = user_project_roles.where(role_id: Role::ADMIN.id).pluck(:project_id)
      scope = scope.where(id: allowed)
    end
    scope
  end

  def self.to_csv
    @users = User.order(:id)
    CSV.generate do |csv|
      csv << ["id","name","email","projectiD","project","role", User.count.to_s + " Users",
        (User.count + UserProjectRole.joins(:user, :project).count).to_s + " Total entries" ]
      @users.find_each do |user|
        csv << [user.id, user.name, user.email, "", "SYSTEM", user.role.name]
        UserProjectRole.where(user_id: user.id).joins(:project).find_each do |user_project_role|
            csv << [user.id, user.name, user.email, user_project_role.project_id, user_project_role.project.name, user_project_role.role.name]
        end
      end
    end
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
    "#{name} (#{email})"
  end

  def gravatar_url
    md5 = email.blank? ? "default" : Digest::MD5.hexdigest(email)
    "https://www.gravatar.com/avatar/#{md5}"
  end

  def is_admin_for?(project)
    is_admin? || !!project_role_for(project).try(:is_admin?)
  end

  def is_deployer_for?(project)
    is_deployer? || !!project_role_for(project).try(:is_deployer?)
  end

  def project_role_for(project)
    user_project_roles.find_by(project: project)
  end

  private

  def set_token
    self.token = SecureRandom.hex
  end
end
