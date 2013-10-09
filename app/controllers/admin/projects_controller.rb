class Admin::ProjectsController < ApplicationController
  before_filter :authorize_admin!

  def show
    @projects = Project.where(deleted_at: nil)
  end
end
