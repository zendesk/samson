Gitlab.configure do |config|
  config.endpoint       = Rails.application.config.samson.gitlab.api_endpoint
  config.private_token  = Rails.application.config.samson.gitlab.api_private_token
  # Optional
  # config.user_agent   = 'Custom User Agent'          # user agent, default: 'Gitlab Ruby Gem [version]'
  # config.sudo         = 'user'                       # username for sudo mode, default: nil
end
