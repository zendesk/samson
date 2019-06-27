# frozen_string_literal: true
class ProfilesController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update_attributes(user_params)
      Rails.logger.info("#{@user.name_and_email} updated their profile to #{@user.name_and_email}")
      redirect_to profile_path, notice: 'Your profile has been updated.'
    else
      render :show
    end
  end

  protected

  def user_params
    params.require(:user).permit(:name, :email, :github_username, :desktop_notify, :time_format)
  end
end
