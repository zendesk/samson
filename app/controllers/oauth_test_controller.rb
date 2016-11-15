# frozen_string_literal: true

# Controller to test OAuth flow by using a self-signed OAuth application, only available in test/dev
class OauthTestController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :ensure_application

  # no user here ... so no tracking needed
  skip_before_action :set_paper_trail_enabled_for_controller
  skip_before_action :set_paper_trail_whodunnit
  skip_before_action :set_paper_trail_controller_info

  def index
    redirect_to oauth_client.auth_code.authorize_url(redirect_uri: token_url)
  end

  def show
    # This can take a long time since it makes a new request to samson itself
    # alternatively we could call whatever the oauth controller does internally directly
    access_token = oauth_client.auth_code.get_token(params[:code], redirect_uri: token_url).token

    render plain: <<-TEXT.strip_heredoc
      Your access token is: #{access_token}

      You can use this to make requests:

      curl -H "Authorization: Bearer #{access_token}" -H "Content-Type: application/json" #{api_projects_url}.json
    TEXT
  rescue OAuth2::Error # getting the token failed ... most likely user refreshed the page
    redirect_to oauth_application_path(application), alert: 'Token has expired ... hit Authorize!'
  end

  private

  # users can have other `real` OAuth apps ... we will find the one that points to samson
  def application
    @application ||= Doorkeeper::Application.where(redirect_uri: token_url).first
  end

  def oauth_client
    OAuth2::Client.new(
      application.uid,
      application.secret,
      site: Rails.configuration.samson.uri.to_s, connection_opts: {ssl: {verify: false}}
    )
  end

  def ensure_application
    return if application
    message = <<-TEXT.strip_heredoc
      Add an OAuth application at

      #{new_oauth_application_url}

      Name: self-signed
      Redirect URI: #{token_url}

      Then click on "Authorize" to get your access token.
    TEXT
    render plain: message
  end

  # we use a fake id to use `resources` routing, because it looks nicer
  def token_url
    url_for action: :show, id: 'token'
  end
end
