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
    user = User.where(external_id: hash[:external_id]).first

    role_id = hash.delete(:role_id)
    user ||= User.new(hash)

    if !User.exists?
      user.role_id = Role::ADMIN.id
    elsif role_id && (user.new_record? || role_id >= user.role_id)
      user.role_id = role_id
    end

    user.save
    user
  end

  def name
    super.presence || email
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
