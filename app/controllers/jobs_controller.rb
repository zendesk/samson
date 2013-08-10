class JobsController < ApplicationController
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_job

  include ActionController::Live

  helper_method :project, :job_history

  def create
    job = project.job_histories.create!(
      user_id: current_user.id,
      environment: create_job_params[:environment],
      sha: create_job_params[:sha])

    Resque.enqueue(Deploy, job.id)

    redirect_to project_job_path(project, job.channel)
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.record.errors.full_messages.join("<br />")
    redirect_to project_path(project)
  end

  def show
  end

  def update
    if job_history.user_id == current_user.id
      Resque.redis.redis.set("#{job_history.channel}:input", message_params[:message])
      head :ok
    else
      head :forbidden
    end
  end

  protected

  def job_params
    params.permit(:id, :environment)
  end

  def create_job_params
    params.require(:job).
      permit(:environment, :sha)
  end

  def message_params
    params.require(:job).
      permit(:message)
  end

  def project
    @project ||= Project.find(params[:project_id])
  end

  def job_history
    @job_history ||= JobHistory.find_by_channel!(params[:id])
  end
end
