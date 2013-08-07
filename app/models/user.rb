class User < ActiveRecord::Base
  def self.find_or_create_from_auth_hash(hash)
    return unless hash.info.email.present?

    user = User.find_by_email(hash.info.email)
    user ||= User.create(:name => hash.info.name, :email => hash.info.email)
    user
  end
end
