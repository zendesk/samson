# frozen_string_literal: true
class UserProjectRolesController < ApplicationController
  include CurrentProject

  before_action :authorize_resource!

  def index
    options = params.to_unsafe_h
    options[:project_id] = current_project.id # override permalink with id
    options[:role_id] = Role::VIEWER.id if options[:role_id].blank? # force the join so we get project_role_id

    @pagy, @users = pagy(
      User.search_by_criteria(options),
      page: params[:page],
      items: 15
    )
    @users = @users.select('users.*, user_project_roles.role_id AS user_project_role_id') # avoid breaking joins

    respond_to do |format|
      format.html
      format.json { render json: {users: @users} }
    end
  end

  def create
    user = User.find(params[:user_id])
    role = UserProjectRole.where(user: user, project: current_project).first_or_initialize

    if role.role_id = params[:role_id].presence
      role.save!
      user.update!(access_request_pending: false)
    elsif role.persisted?
      role.destroy!
    end

    role_name = (role.role_id ? role.role.display_name : 'None')
    Rails.logger.info(
      "#{current_user.name_and_email} set the role #{role_name} to #{user.name} on project #{current_project.name}"
    )

    if request.xhr?
      render plain: "Saved!"
    else
      redirect_back fallback_location: "/", notice: "Saved!"
    end
  end
end
