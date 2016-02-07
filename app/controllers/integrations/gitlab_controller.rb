class Integrations::GitlabController < Integrations::BaseController

  protected

  def deploy?
    valid_payload?
  end

  def valid_payload?
    request.headers['X-Gitlab-Event'] == 'Push Hook'
  end

  def commit
    params[:after]
  end

  def branch
    # Github returns full ref e.g. refs/heads/...
    params[:ref][/refs\/heads\/(.+)/, 1]
  end

  private

  def service_type
    'code'
  end
end
