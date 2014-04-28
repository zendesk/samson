require 'soft_deletion'
require 'digest/md5'

class User < ActiveRecord::Base
  has_soft_deletion default_scope: true

  has_many :commands
  has_many :stars
  has_many :starred_projects, through: :stars, source: :project

  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  before_create :set_token

  def starred_project?(project)
    starred_projects.include?(project)
  end

  def self.create_or_update_from_hash(hash)
    user = User.where(email: hash[:email]).first
    user ||= User.new

    role_id = hash.delete(:role_id)

    if role_id && (user.new_record? || role_id >= user.role_id)
      user.role_id = role_id
    end

    user.attributes = hash
    unless User.exists?
      user.role_id = Role::SUPER_ADMIN.id
    end
    user.tap(&:save)
  end

  def name
    super.presence || email
  end

  def name_and_email
    "#{name} (#{email})"
  end

  def gravatar_url
    md5 = Digest::MD5.hexdigest(email)
    "http://www.gravatar.com/avatar/#{md5}"
  end

  Role.all.each do |role|
    define_method "is_#{role.name}?" do
      role_id >= role.id
    end
  end

  private

  def set_token
    self.token = SecureRandom.hex
  end
end
