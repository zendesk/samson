# frozen_string_literal: true
class UserProjectRolesController < ApplicationController
  include CurrentProject

  before_action :authorize_project_admin!, except: [:index]

  def index
    options = params.to_unsafe_h
    options[:project_id] = current_project.id # override permalink with id
    options[:role_id] = Role::VIEWER.id if options[:role_id].blank? # force the join so we get project_role_id

    @users = User.search_by_criteria(options)
    @users = @users.select('users.*, user_project_roles.role_id AS user_project_role_id')

    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end

  def create
    user = User.find(params[:user_id])
    role = UserProjectRole.where(user: user, project: current_project).first_or_initialize
    role.role_id = params[:role_id].presence

    if role.role_id
      role.save!
      user.update!(access_request_pending: false)
    elsif role.persisted?
      role.destroy!
    end

    role_name = (role.role.try(:display_name) || 'None')
    Rails.logger.info(
      "#{current_user.name_and_email} set the role #{role_name} to #{user.name} on project #{current_project.name}"
    )

    if request.xhr?
      render plain: "Saved!"
    else
      redirect_back_or "/", notice: "Saved!"
    end
  end
end
