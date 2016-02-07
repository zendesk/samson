class Integrations::GitlabController < Integrations::BaseController

  protected

  def deploy?
    valid_payload?
  end

  def valid_payload?
    request.headers['X-Gitlab-Event'] == 'Push Hook'
  end

  def commit
    # Gitlab returns full ref e.g. refs/heads/...
    params[:ref][/refs\/heads\/(.+)/, 1]
  end

  def branch
    # Gitlab returns full ref e.g. refs/heads/...
    params[:ref][/refs\/heads\/(.+)/, 1]
  end

  private

  def service_type
    'code'
  end
end
