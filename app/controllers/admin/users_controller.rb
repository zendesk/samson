class Admin::UsersController < ApplicationController
  def show
    @users = User.all
  end

  def update
    User.transaction do
      users = User.where(id: user_params.keys)

      users.each do |user|
        role = user_params[user.id.to_s][:role]
        user.update_attributes!(:role_id => role)
      end
    end

    flash[:notice] = "Successfully updated users."
  rescue ActiveRecord::Rollback
    flash[:error] = "Could not update users."
  ensure
    redirect_to admin_users_path
  end

  protected

  def user_params
    params.require(:users).permit!
  end
end
