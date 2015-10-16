class ReferencesController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_project_deployer!

  def index
    @references = ReferencesService.new(@project).find_git_references
    render json: @references, root: false
  end
end
