class ReferencesController < ApplicationController
  before_filter :find_project
  before_filter :authorize_deployer!

  def index
    @references = ReferencesService.new(@project).find_git_references
    render json: @references, root: false
  end
end
