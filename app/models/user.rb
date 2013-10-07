class User < ActiveRecord::Base
  validates :role_id, inclusion: { in: Role.all.map(&:id) }
  validates :current_token, presence: true

  def self.find_or_create_from_oauth(hash, strategy)
    return unless hash.info.email.present?

    user = User.find_by_email(hash.info.email)

    # If the user already has a token, delete it
    if user.try(:current_token)
      current_token = OAuth2::AccessToken.new(oauth_client, user.current_token)
      delete_token(current_token)
    end

    access_token = strategy.access_token
    delete_token(access_token)

    user ||= User.create(:name => hash.info.name, :email => hash.info.email, :current_token => access_token.token)
    user
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
