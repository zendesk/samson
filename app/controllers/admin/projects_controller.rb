class Admin::ProjectsController < ApplicationController
  before_action :authorize_admin!

  def show
    @projects = Project.page(params[:page])
  end
end
