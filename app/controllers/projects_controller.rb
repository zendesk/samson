class ProjectsController < ApplicationController
  def index
    @projects = Project.limit(9).includes(job_histories: :user, job_locks: nil)
  end

  def show
    @project = Project.find(params[:id])
  end
end
