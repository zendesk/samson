class StarsController < ApplicationController
  before_filter :find_project

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

  def find_project
    @project = Project.find_by_param!(params[:id])
  end
end
