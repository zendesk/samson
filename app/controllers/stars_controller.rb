class StarsController < ApplicationController
  load_resource :project, find_by: :param

  def create
    current_user.stars.create!(project: @project)

    head :ok
  end

  def destroy
    star = current_user.stars.find_by_project_id(@project.id)
    star && star.destroy

    head :ok
  end
end
