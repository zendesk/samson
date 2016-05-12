class UsersController < ApplicationController
  include CurrentProject

  before_action :authorize_project_admin!

  def index
    @users = User.search_by_criteria(params)
    if role_id = params[:role_id]
      @users = @users.with_role(role_id, current_project.id)
    end

    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end
end
