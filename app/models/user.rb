class User < ActiveRecord::Base
  paginates_per 50
  has_many :commands

  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  before_create :set_current_token

  def self.create_or_update_from_hash(hash)
    user = User.where(email: hash[:email]).first
    user ||= User.new

    role_id = hash.delete(:role_id)

    if role_id && (user.new_record? || role_id >= user.role_id)
      user.role_id = role_id
    end

    user.attributes = hash
    user.tap(&:save)
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
