class JobsController < ApplicationController
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_job
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
      sha: create_job_params[:sha])

    Thread.main[:deploys] << Thread.new do
      Thread.current[:deploy] = deploy = Deploy.new(job.id)
      deploy.perform
      Thread.main[:deploys].delete(Thread.current)
    end

    redirect_to project_job_path(project, job)
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.record.errors.full_messages.join("<br />").html_safe
    redirect_to project_path(project)
  end

  def show
    if !job_history
      render :status => 404
    end
  end

  def update
    if message_params[:message].blank?
      head :unprocessable_entity
    elsif job_history.user_id == current_user.id
      redis = Redis.driver
      redis.set("#{job_history.channel}:input", message_params[:message])
      redis.quit

      head :ok
    else
      head :forbidden
    end
  end

  def destroy
    if deploy = current_deploy
      deploy.stop

      head :ok
    else
      head :not_found
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

  def current_deploy
    @current_deploy ||= Thread.main[:deploys].detect {|thread|
      thread[:deploy].job_id == job_history.id
    }.try(:[], :deploy)
  end

  def invalid_job
    # TODO
  end
end
