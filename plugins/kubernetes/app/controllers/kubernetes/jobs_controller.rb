class Kubernetes::JobsController < ApplicationController
  include CurrentProject

  before_action :authorize_project_admin!, only: [:new, :create, :destroy]
  before_action :find_task, except: [:stream]

  def new
    @job = @task.kubernetes_jobs.build
  end

  def create
    @job = Kubernetes::JobService.new(current_user).run!(@task, job_params)

    if @job.persisted?
      redirect_to project_kubernetes_job_path(@project, @job, kubernetes_task_id: @task)
    else
      render :new
    end
  end

  def index
    @jobs = @task.kubernetes_jobs.page(params[:page])
  end

  def show
    @job = @task.kubernetes_jobs.find(params[:id])
    respond_to do |format|
      format.html
      format.text do
        datetime = @job.updated_at.strftime("%Y%m%d_%H%M%Z")
        send_data @job.output,
          type: 'text/plain',
          filename: "#{@project.repo_name}-#{@job.id}-#{datetime}.log"
      end
    end
  end

  private

  def find_task
    @task = Kubernetes::Task.not_deleted.find(params[:kubernetes_task_id])
  end

  def job_params
    params.require(:kubernetes_job).permit(:stage_id, :commit)
  end

end
