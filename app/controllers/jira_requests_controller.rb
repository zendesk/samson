class JiraRequestsController < ApplicationController
  protect_from_forgery
  before_action :get_jira_client

  rescue_from JIRA::OauthClient::UninitializedAccessTokenError do
    # JIRA call failed (we're not authorized) - start the OAuth dance
    redirect_to action: 'authorize'
  end

  rescue_from OAuth::Unauthorized do
    # user chose 'Deny' on JIRA authorization page
    ticket_fail
    redirect_to session.delete(:jira_back_to)
  end

  def ticket
    #to be able to trace back to where the request originated from
    session[:jira_back_to] ||= request.referer

    issue = @jira_client.Issue.build
    fields = {
        'summary' => ENV['JIRA_ISSUE_SUMMARY'],
        'description' => ENV['JIRA_ISSUE_DESCRIPTION'],
        'project' => {'id' => ENV['JIRA_ISSUE_PROJECT_ID']},
        'issuetype' => {'id' => ENV['JIRA_ISSUE_TYPE']},
        'priority' => {'id' => ENV['JIRA_ISSUE_PRIORITY']}
    }
    status = issue.save({'fields' => drop_nil_values(fields)})

    status ? ticket_success : ticket_fail
    redirect_to session.delete(:jira_back_to)
  end

  def authorize
    request_token = @jira_client.request_token(oauth_callback: jira_requests_callback_url)
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret
    redirect_to request_token.authorize_url
  end

  def callback
    @jira_client.set_request_token(session[:request_token], session[:request_secret])
    access_token = @jira_client.init_access_token(oauth_verifier: params[:oauth_verifier])
    session[:jira_auth] = {access_token: access_token.token, access_key: access_token.secret}

    session.delete(:request_token)
    session.delete(:request_secret)

    redirect_to action: 'ticket'
  end

  private

  def get_jira_client
    options = {
        site: ENV['JIRA_SITE'],
        context_path: ENV['JIRA_CONTEXT_PATH'],
        rest_base_path: ENV['JIRA_REQUEST_BASE_PATH'],
        private_key_file: ENV['JIRA_PRIVATE_KEY_FILE'],
        consumer_key: ENV['JIRA_CONSUMER_KEY']
    }
    @jira_client = JIRA::Client.new(drop_nil_values(options))

    # reuse access token if authorised previously.
    if session[:jira_auth]
      @jira_client.set_access_token(session[:jira_auth][:access_token], session[:jira_auth][:access_key])
    end
  end

  def ticket_success
    flash[:success] = 'JIRA ticket created.'
  end

  def ticket_fail
    flash[:error] = 'Could not create JIRA ticket.'
  end

  def drop_nil_values(hash)
    # helper for ignoring missing config in ENV
    hash.select { |_, value| value.is_a?(Hash) ? value['id'] : value }
  end
end
