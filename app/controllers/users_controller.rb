class UsersController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_project_admin!

  def index
    @users = User.search_by_criteria(params)

    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end
end
