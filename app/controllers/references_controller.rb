class ReferencesController < ApplicationController
  rescue_from(ActiveRecord::RecordNotFound) { head :not_found }

  before_filter :find_project
  before_filter :authorize_deployer!

  def index
    render json: references, root: false
  end

  private

  def references
    # TODO grab 'git branch -l && git tag -l' from repo_cache_dir after a quick sync/check
    ["v3.3", "v3.3.0", "v3.3.1", "v3.3.10", "v3.3.2", "v3.3.3", "v3.3.4", "v3.3.5", "v3.4", "v3.4.0", "v3.4.1", "v3.4.2", "v3.4.3", "v3.4.4"]
  end

  def find_project
    @project = Project.find_by_param!(params[:project_id])
  end
end
