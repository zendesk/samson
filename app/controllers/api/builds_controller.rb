# frozen_string_literal: true
class Api::BuildsController < Api::BaseController
  include CurrentProject

  before_action :authorize_resource!

  def create
    build_params = params.require(:build)
    digest = extract_param(build_params, :docker_repo_digest)
    sha = extract_param(build_params, :git_sha)

    Samson::Hooks.fire(:before_docker_repository_usage, current_project)

    build = current_project.builds.create!(
      build_params.permit(*Build::ASSIGNABLE_KEYS).merge(
        creator: current_user,
        docker_repo_digest: digest,
        git_sha: sha
      )
    )

    Samson::Hooks.fire(:after_docker_build, build)

    head :created
  end

  private

  # show a nice error when not present but remove it so .permit does not crash
  def extract_param(build_params, param)
    build_params.require(param) && build_params.delete(param)
  end
end
