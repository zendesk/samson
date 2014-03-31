class ReleasesController < ApplicationController
  before_filter :find_project

  def index
    
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  end
end
