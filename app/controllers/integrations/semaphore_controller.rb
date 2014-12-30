class Integrations::SemaphoreController < Integrations::BaseController
  protected

  def deploy?
    params[:result] == 'passed' &&
      !skip?
  end

  def skip?
    contains_skip_token?(params[:commit][:message])
  end

  def commit
    params[:commit][:id]
  end

  def branch
    params[:branch_name]
  end

  def user
    name = "Semaphore"
    email = "deploy+semaphore@#{Rails.application.config.samson.email.sender_domain}"

    User.create_with(name: name).find_or_create_by(email: email)
  end
end
