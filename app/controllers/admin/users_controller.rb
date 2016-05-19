require 'csv'

class Admin::UsersController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [:update, :destroy]

  def index
    @users = User.search_by_criteria(params)
    respond_to do |format|
      format.html
      format.json { render json: @users }
      format.csv do
        datetime = Time.now.strftime "%Y%m%d_%H%M"
        send_data User.to_csv, type: :csv, filename: "Users_#{datetime}.csv"
      end
    end
  end

  def show
    @user = User.find(params[:id])
    @projects = Project.search_by_criteria(params)
  end

  def update
    if user.update_attributes(user_params)
      Rails.logger.info(
        "#{current_user.name_and_email} changed the role of #{user.name_and_email} to #{user.role.name}"
      )
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
    # also reset pending access request, so the user can request further access rights
    params.require(:user).permit(:role_id).merge(access_request_pending: false)
  end
end
