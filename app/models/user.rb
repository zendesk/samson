class User < ActiveRecord::Base
  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  def self.find_or_create_from_oauth(hash, strategy)
    return unless hash.info.email.present?

    user = User.find_by_email(hash.info.email)
    user ||= User.new

    access_token = strategy.access_token
    delete_token(access_token)

    user.attributes = { :name => hash.info.name, :email => hash.info.email, :current_token => access_token.token }
    user.tap(&:save)
  end

  Role.all.each do |role|
    define_method "is_#{role.name}?" do
      role_id >= role.id
    end
  end

  private

  # Takes an OAuth2::AccessToken
  def self.delete_token(token)
    token_id = token.get('/api/v2/oauth/tokens/current.json').parsed['token']['id']
    token.delete("/api/v2/oauth/tokens/#{token_id}.json")
  end
end
