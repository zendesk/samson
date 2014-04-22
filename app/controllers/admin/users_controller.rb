class Admin::UsersController < ApplicationController
  before_filter :authorize_admin!
  helper_method :sort_column, :sort_direction

  def show
    @users = User.order(sort_column + ' ' + sort_direction).page(params[:page])
  end

  def update
    User.transaction do
      users = User.where(id: user_params.keys)

      users.each do |user|
        role = user_params[user.id.to_s][:role]
        user.update_attributes!(role_id: role)
      end
    end

    flash[:notice] = "Successfully updated users."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    flash[:error] = "Could not update users."
  ensure
    redirect_to admin_users_path
  end

  def destroy
    User.find(params[:id]).soft_delete!

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
    %w[asc desc].include?(params[:direction]) ?  params[:direction] : "asc"
  end
end
