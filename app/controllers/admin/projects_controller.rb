class Admin::ProjectsController < ApplicationController
  def show
    @projects = Project.all
  end
end
