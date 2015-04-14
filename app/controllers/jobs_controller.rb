class JobsController < ApplicationController
  before_filter :authorize_admin!, only: [:new, :create, :destroy]

  before_action :find_project, except: [:enabled]
  before_action :find_job, only: [:show, :destroy]

  def index
    @jobs = @project.jobs.non_deploy.page(params[:page])
  end

  def new
    @job = Job.new
  end

  def create
    job_service = JobService.new(@project, current_user)
    command_ids = command_params[:ids].select(&:present?)

    @job = job_service.execute!(
      job_params[:commit].strip, command_ids,
      job_params[:command].strip.presence
    )

    if @job.persisted?
      JobExecution.start_job(job_params[:commit].strip, @job)
      redirect_to [@project, @job]
    else
      render :new
    end
  end

  def show
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

  def enabled
    if JobExecution.enabled
      head :no_content
    else
      head :accepted
    end
  end

  def destroy
    if @job.started_by?(current_user) || current_user.is_admin?
      @job.stop!

      head :ok
    else
      head :forbidden
    end
  end

  private

  def job_params
    params.require(:job).permit(:commit, :command)
  end

  def command_params
    params.require(:commands).permit(ids: [])
  end

  def find_project
    @project = Project.find_by_param!(params[:project_id])
  end

  def find_job
    @job = @project.jobs.find(params[:id])
  end
end
