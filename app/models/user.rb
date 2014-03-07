require 'soft_deletion'
require 'digest/md5'

class User < ActiveRecord::Base
  has_soft_deletion default_scope: true

  has_many :commands

  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  before_create :set_current_token

  def self.create_or_update_from_hash(hash)
    user = User.where(email: hash[:email]).first
    user ||= User.new

    role_id = hash.delete(:role_id)

    if role_id && (user.new_record? || role_id >= user.role_id)
      user.role_id = role_id
    elsif !User.exists?
      user.role_id = Role::ADMIN.id
    end

    user.attributes = hash
    user.tap(&:save)
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

  def set_current_token
    self.current_token = SecureRandom.hex
  end
end
