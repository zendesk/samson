# frozen_string_literal: true
class UsersController < ApplicationController
  include CurrentProject

  before_action :authorize_project_admin!

  def index
    @users = User.search_by_criteria(params.merge(project_id: current_project.id))

    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end
end
