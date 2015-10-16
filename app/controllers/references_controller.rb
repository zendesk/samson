class ReferencesController < ApplicationController
  include CurrentProject

  before_action :authorize_deployer!
  before_action do
    find_project(params[:project_id])
  end

  def index
    @references = ReferencesService.new(@project).find_git_references
    render json: @references, root: false
  end
end
