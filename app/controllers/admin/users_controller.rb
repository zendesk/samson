class Admin::UsersController < ApplicationController
  before_filter :authorize_admin!
  before_filter :authorize_super_admin!, only: [ :update, :destroy ]
  helper_method :sort_column, :sort_direction

  def show
    @users = User.order(sort_column + ' ' + sort_direction).page(params[:page])
  end

  def update
    User.transaction do
      users = User.where(id: user_params.keys)

      users.each do |user|
        role = user_params[user.id.to_s][:role]
        user.role_id = role
        if user.changed?
          user.update_attributes!(role_id: role)
          Rails.logger.info("#{current_user.name_and_email} changed the role of #{user.name_and_email} to #{Role.find(role).name}")
        end
      end
    end

    flash[:notice] = "Successfully updated users."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    flash[:error] = "Could not update users."
  ensure
    redirect_to admin_users_path
  end

  def destroy
    user = User.find(params[:id])
    user.soft_delete!
    Rails.logger.info("#{current_user.name_and_email} just deleted #{user.name_and_email})")
    redirect_to admin_users_path
  end

  protected

  def user_params
    params.require(:users).permit!
  end

  private

  def sort_column
    User.column_names.include?(params[:sort]) ? params[:sort] : "created_at"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end
end
