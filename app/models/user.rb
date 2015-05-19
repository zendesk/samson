require 'soft_deletion'
require 'digest/md5'

class User < ActiveRecord::Base
  include HasRole

  has_soft_deletion default_scope: true

  has_many :commands
  has_many :stars
  has_many :starred_projects, through: :stars, source: :project
  has_many :locks, dependent: :destroy
  has_many :project_roles

  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  before_create :set_token

  scope :search, ->(query) { where("name like ? or email like ?", "%#{query}%", "%#{query}%") }

  def starred_project?(project)
    starred_projects.include?(project)
  end

  def self.create_or_update_from_hash(hash)
    user = User.where(external_id: hash[:external_id].to_s).first || User.new

    # attributes are always a string hash
    attributes = user.attributes.merge(hash.stringify_keys) do |key, old, new|
      if key == 'role_id'
        if !User.exists?
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

  def admin_for?(project)
    is_admin? || project_roles.where(project: project).try(:is_admin?)
  end

  def deployer_for?(project)
    is_deployer? || project_roles.where(project: project).try(:is_deployer?)
  end

  private

  def set_token
    self.token = SecureRandom.hex
  end
end
