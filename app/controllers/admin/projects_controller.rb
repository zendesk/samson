class Admin::ProjectsController < ApplicationController
  before_filter :authorize_admin!

  def show
    @projects = Project.page(params[:page])
  end
end
