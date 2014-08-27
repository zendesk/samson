class Admin::UsersController < ApplicationController
  before_filter :authorize_admin!
  before_filter :authorize_super_admin!, only: [ :update, :destroy ]
  helper_method :sort_column, :sort_direction

  def index
    @users = User.order(sort_column + ' ' + sort_direction).page(params[:page])
    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end

  def update
    if user.update_attributes(user_params)
      role = Role.find(user_params[:role_id]).name
      Rails.logger.info("#{current_user.name_and_email} changed the role of #{user.name_and_email} to #{role}")
      head :ok
    else
      head :bad_request
    end
  end

  def destroy
    user = User.find(params[:id])
    user.soft_delete!
    Rails.logger.info("#{current_user.name_and_email} just deleted #{user.name_and_email})")
    redirect_to admin_users_path
  end

  private

  def user_params
    params.permit(:id, :role_id)
  end

  def user
    @user ||= User.find(params[:id])
  end

  def sort_column
    User.column_names.include?(params[:sort]) ? params[:sort] : "created_at"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end
end
