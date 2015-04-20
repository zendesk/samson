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
end
