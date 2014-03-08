class JobsController < ApplicationController
  before_filter :find_project, only: [:new, :create, :show]

  def new
    @job = Job.new
  end

  def create
    reference = job_params[:commit].strip

    command = command_params[:ids].select(&:present?).map do |command_id|
      Command.find(command_id).command
    end

    command << job_params[:command].strip

    @job = @project.jobs.create(
      user: current_user,
      command: command.join("\n"),
      commit: reference
    )

    if @job.persisted?
      JobExecution.start_job(job_params[:commit].strip, @job)
      redirect_to project_job_path(@project, @job)
    else
      render :new
    end
  end

  def show
    @job = Job.find(params[:id])
  end

  def enabled
    if JobExecution.enabled
      head :no_content
    else
      head :accepted
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
    @project = Project.find(params[:project_id])
  end
end
