class Admin::UsersController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :update, :destroy ]
  helper_method :sort_column, :sort_direction

  def index
    scope = User
    scope = scope.search(params[:search]) if params[:search]
    @users = scope.order(sort_column + ' ' + sort_direction).page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end

  def show
    @user = User.find(params[:id])

    scope = Project
    scope = scope.search(params[:search]) if params[:search]
    @projects = scope.order("#{sort_column} #{sort_direction}").page(params[:page])
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

  def sort_column
    User.column_names.include?(params[:sort]) ? params[:sort] : "created_at"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end
end
