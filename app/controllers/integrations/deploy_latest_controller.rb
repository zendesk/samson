class Integrations::DeployLatestController < ApplicationController
  skip_before_action :login_users
  skip_before_action :verify_authenticity_token

  before_filter :ensure_secret_token_matches

  def create
    if deploy_release?
      DeployService.new(project, user).deploy!(stage, latest_release.commit)
      head 200
    else
      head 422
    end
  end

  private

  def project
    @project ||= Project.find_by_token!(params[:token])
  end

  def stage
    @stage ||= project.stages.find_by_permalink!(params[:stage])
  end

  def latest_release
    @latest_release ||= project.releases.last
  end

  def deploy_release?
    latest_release.present? && !stage.currently_deploying? && !stage.current_release?(latest_release)
  end

  def user
    return @user if defined?(@user)
    email = "deploy+webhook@#{Rails.application.config.samson.email.sender_domain}"
    @user = User.create_with(name: 'Webhook', integration: true).find_or_create_by(email: email)
  end

  def ensure_secret_token_matches
    if webhook_secret.blank? || request.headers['X-Webhook-Secret'] != webhook_secret
      render status: 401, text: 'incorrect webhook secret'
    end
  end

  def webhook_secret
    Rails.application.config.samson.webhook_secret
  end
end
