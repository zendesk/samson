class JobsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do |error|
    flash[:error] = "Job not found."
    redirect_to root_path
  end

  before_filter :authorize_deployer!, only: [:create, :update, :destroy]

  helper_method :project, :job_history, :job_histories

  def index
  end

  def active
    render :index
  end

  def create
    job = project.job_histories.create!(
      user_id: current_user.id,
      environment: create_job_params[:environment],
      sha: create_job_params[:sha]
    )

    enqueue_job(job)

    redirect_to project_job_path(project, job)
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.record.errors.full_messages.join("<br />").html_safe
    redirect_to project_path(project)
  end

  def show
  end

  def update
    if message_params[:message].blank?
      head :unprocessable_entity
    elsif job_history.user_id != current_user.id
      head :forbidden
    else
      send_message("#{job_history.channel}:input", message_params[:message])

      head :ok
    end
  end

  def destroy
    if job_history.user_id != current_user.id
      head :forbidden
    else
      send_message("#{job_history.channel}:stop", "true")

      head :ok
    end
  end

  protected

  def job_params
    params.permit(:id, :environment, :project_id)
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

  def job_histories_scope
    if action_name == "active"
      JobHistory.active
    else
      JobHistory
    end
  end

  def job_histories
    @job_histories ||= job_histories_scope.limit(10).order("created_at DESC")
  end

  def send_message(channel, message)
    redis = Redis.driver
    redis.set(channel, message)
    redis.quit
  end
end
