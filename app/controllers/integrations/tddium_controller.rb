class Integrations::TddiumController < Integrations::BaseController
  protected

  def deploy?
    params[:status] == 'passed' &&
      params[:event] == 'stop'
  end

  def branch
    params[:branch]
  end

  def commit
    params[:commit_id]
  end

  def user
    name = "Tddium"
    email = "deploy+tddium@zendesk.com"

    User.create_with(name: name).find_or_create_by(email: email)
  end
end
