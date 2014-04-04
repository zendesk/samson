class ChangelogsController < ApplicationController
  def show
    @start_date = Date.today.beginning_of_week - 3.days

    @project = Project.find(params[:project_id])
    @changeset = Changeset.find(@project.github_repo, "master@{#{@start_date}}", "master@{#{Date.today}}")
  end
end
