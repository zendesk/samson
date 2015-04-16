class Admin::UsersController < ApplicationController
  load_and_authorize_resource class: User, except: :index
  helper_method :sort_column, :sort_direction
#
  def index
    authorize! :admin_read, User
    scope = User
    scope = scope.search(params[:search]) if params[:search]
    @users = scope.order(sort_column + ' ' + sort_direction).page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end

  def update
    if @user.update_attributes(user_params)
      Rails.logger.info("#{current_user.name_and_email} changed the role of #{@user.name_and_email} to #{@user.role.name}")
      head :ok
    else
      head :bad_request
    end
  end

  def destroy
    @user.soft_delete!
    Rails.logger.info("#{current_user.name_and_email} just deleted #{@user.name_and_email})")
    redirect_to admin_users_path
  end

  private

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
