class Integrations::BuildkiteController < Integrations::BaseController
  protected

  def deploy?
    build_event? && build_passed? && no_skip_token_present?
  end

  def build_event?
    request.headers['X-Buildkite-Event'] == 'build'
  end

  def build_passed?
    params[:build][:state] == 'passed'
  end

  def no_skip_token_present?
    !contains_skip_token?(params[:build][:message])
  end

  def commit
    params[:build][:commit]
  end

  def branch
    params[:build][:branch]
  end
end
