class StarsController < ApplicationController
  include CurrentProject

  def create
    current_user.stars.create!(project: @project)

    head :ok
  end

  def destroy
    star = current_user.stars.find_by_project_id(@project.id)
    star && star.destroy

    head :ok
  end

  private

  def require_project
    # override from CurrentProject
    @project = (Project.find_by_param!(params[:id]) if params[:id])
  end
end
