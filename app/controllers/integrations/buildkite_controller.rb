# frozen_string_literal: true
class Integrations::BuildkiteController < Integrations::BaseController
  protected

  def deploy?
    build_passed?
  end

  def build_passed?
    build_param[:state] == 'passed'
  end

  def commit
    build_param[:commit]
  end

  def branch
    build_param[:branch]
  end

  def build_param
    @build_param ||= params.fetch(:build, {})
  end

  def message
    build_param[:message]
  end

  def release_params
    extra_params = Samson::Hooks.fire(:buildkite_release_params, project, build_param)
    super.merge(Hash[*extra_params.flatten])
  end
end
