class ReferencesController < ApplicationController
  include CurrentProject
  include ProjectLevelAuthorization

  before_action do
    find_project(params[:project_id])
  end

  before_action :authorize_project_deployer!

  def index
    @references = ReferencesService.new(@project).find_git_references
    render json: @references, root: false
  end
end
