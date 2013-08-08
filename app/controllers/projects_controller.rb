class ProjectsController < ApplicationController
  def index
    @projects = Project.all(limit: 9)
  end

  def show
    @project = Project.find(params[:id])
  end
end
