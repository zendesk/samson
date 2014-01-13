class User < ActiveRecord::Base
  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  def self.create_or_update_from_hash(hash)
    user = User.where(email: hash[:email]).first
    user ||= User.new

    user.attributes = hash
    user.tap(&:save)
  end

  Role.all.each do |role|
    define_method "is_#{role.name}?" do
      role_id >= role.id
    end
  end
end
