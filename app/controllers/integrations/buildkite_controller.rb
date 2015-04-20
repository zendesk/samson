class Integrations::BuildkiteController < Integrations::BaseController
  protected

  def deploy?
    build_passed? && no_skip_token_present?
  end

  def build_passed?
    build_param[:state] == 'passed'
  end

  def no_skip_token_present?
    !contains_skip_token?(build_param[:message])
  end

  def commit
    build_param[:commit]
  end

  def branch
    build_param[:branch]
  end

  def build_param
    @build_param ||= params.fetch(:build, { })
  end
end
