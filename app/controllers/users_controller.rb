# frozen_string_literal: true
class UsersController < ApplicationController
  include CurrentProject

  before_action :authorize_project_admin!

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
end
