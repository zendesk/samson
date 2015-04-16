class ReferencesController < ApplicationController
  load_resource :project, find_by: :param
  authorize_resource class: ReferencesService

  def index
    @references = ReferencesService.new(@project).find_git_references
    render json: @references, root: false
  end
end
