class Admin::LocksController < ApplicationController
  before_action :authorize_admin!

  def create
    Lock.create(user: current_user)
    redirect_to admin_projects_path
  end

  def destroy
    Lock.global.first.try(:soft_delete)
    redirect_to admin_projects_path
  end
end
