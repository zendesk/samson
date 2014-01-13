class Warden::Strategies::ZendeskOAuth2Strategy < Warden::Strategies::Base
  def valid?; true; end

  def authenticate!
    redirect!('/auth/zendesk')
  end
end

Warden::Strategies.add(:zendesk_oauth2, Warden::Strategies::ZendeskOAuth2Strategy)
