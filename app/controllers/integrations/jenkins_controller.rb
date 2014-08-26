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
    email = "deploy+jenkins@samson-deployment.com"

    User.create_with(name: name).find_or_create_by(email: email)
  end
end
