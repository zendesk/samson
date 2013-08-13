class User < ActiveRecord::Base
  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  def self.find_or_create_from_auth_hash(hash)
    return unless hash.info.email.present?

    user = User.find_by_email(hash.info.email)
    user ||= User.create(:name => hash.info.name, :email => hash.info.email)
    user
  end

  Role.all.each do |role|
    define_method "is_#{role.name}?" do
      role_id >= role.id
    end
  end
end
