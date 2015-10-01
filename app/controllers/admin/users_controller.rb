class Admin::UsersController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :update, :destroy ]

  def index
    @users = User.search_by_criteria(params)
    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end

  def show
    @user = User.find(params[:id])
    @projects = Project.search_by_criteria(params)
  end

  def update
    if user.update_attributes(user_params)
      Rails.logger.info("#{current_user.name_and_email} changed the role of #{user.name_and_email} to #{user.role.name}")
      head :ok
    else
      head :bad_request
    end
  end

  def destroy
    user.soft_delete!
    Rails.logger.info("#{current_user.name_and_email} just deleted #{user.name_and_email})")
    redirect_to admin_users_path
  end

  private

  def user
    @user ||= User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:role_id)
  end
end
