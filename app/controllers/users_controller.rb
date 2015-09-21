class UsersController < ApplicationController
  include CurrentProject
  include ProjectLevelAuthorization

  helper_method :sort_column, :sort_direction

  before_action do
    find_project(params[:project_id])
  end

  before_action :authorize_project_admin!

  def index
    scope = User
    scope = scope.search(params[:search]) if params[:search]
    @users = scope.order(sort_column + ' ' + sort_direction).page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end

  def sort_column
    User.column_names.include?(params[:sort]) ? params[:sort] : "created_at"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end

end
