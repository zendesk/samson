class Integrations::SemaphoreController < Integrations::BaseController
  protected

  def deploy?
    params[:result] == 'passed' &&
      !skip?
  end

  def skip?
    params[:commit][:message].include?("[deploy skip]")
  end

  def commit
    params[:commit][:id]
  end

  def branch
    params[:branch_name]
  end

  def user
    name = "Semaphore"
    email = "deploy+semaphore@zendesk.com"

    User.create_with(name: name).find_or_create_by(email: email)
  end
end
