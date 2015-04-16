class Admin::ProjectsController < ApplicationController

  def show
    authorize! :admin_read, Project
    @projects = Project.page(params[:page])
  end
end
