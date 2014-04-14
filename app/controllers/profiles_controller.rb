class ProfilesController < ApplicationController

  def update
    @user = current_user

    if @user.update_attributes(user_params)
      redirect_to profile_path, notice: 'Your profile has been updated.'
    else
      render action: "show"
    end
  end

  def show
    @user = current_user
  end

  protected

  def user_params
    params.require(:user).permit(
      :name
    )
  end

end
