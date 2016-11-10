# frozen_string_literal: true
class Admin::UserMergesController < ApplicationController
  before_action :authorize_super_admin!
  before_action :find_user

  def new
  end

  def create
    target = User.find(params[:merge_target_id])
    @user.update_attributes!(external_id: target.external_id)
    target.soft_delete!
    Samson::Hooks.fire(:merged_user, current_user, @user, target)
    redirect_to [:admin, @user], notice: "Merge successful."
  end

  private

  def find_user
    @user = User.find(params[:user_id])
  end
end
