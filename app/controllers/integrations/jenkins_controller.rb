class Integrations::JenkinsController < Integrations::BaseController
  protected

  def deploy?
    params[:build][:status] == 'SUCCESS'
  end

  def commit
    params[:build][:scm][:commit]
  end

  def branch
    params[:build][:scm][:branch]
  end

  def user
    name = "Jenkins"
    email = "deploy+jenkins@#{Rails.application.config.samson.email.sender_domain}"

    User.create_with(name: name).find_or_create_by(email: email)
  end
end
