class User < ActiveRecord::Base
  has_many :commands

  validates :role_id, inclusion: { in: Role.all.map(&:id) }

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

  def self.semaphore_user
    name = "Semaphore"
    email = "semaphore@renderedtext.com"

    create_with(name: name).find_or_create_by(email: email)
  end

  Role.all.each do |role|
    define_method "is_#{role.name}?" do
      role_id >= role.id
    end
  end
end
