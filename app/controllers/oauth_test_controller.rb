class OauthTestController < ActionController::Base
  before_action :ensure_application

  def index
    redirect_to client.auth_code.authorize_url(redirect_uri: test_application_url)
  end

  def show
    token = client.auth_code.get_token(params[:code], redirect_uri: test_application_url)
    render plain: <<-MESSAGE.strip_heredoc
    Your access token is: #{params[:code]}

    You can use this to make requests:

    curl -H "Authorization: Bearer #{params[:code]}" -H "Content-Type: application/json" #{api_projects_url}.json
    MESSAGE
  end

  private

  def application
    @application ||= Doorkeeper::Application.where(redirect_uri: test_application_url).first
  end

  def client
    OAuth2::Client.new(
      application.uid,
      application.secret,
      site: Rails.configuration.samson.uri.to_s, connection_opts: {ssl: {verify: false}}
    )
  end

  def ensure_application
    return if application
    message = <<-WARN.strip_heredoc
      Add an OAuth application at

      #{new_oauth_application_url}

      and set the redirect URI to: #{test_application_url}

      Then come back here.
    WARN
    render plain: message
  end

  def test_application_url
    oauth_test_url(1)
  end
end