class JobsController < ApplicationController
  include ApplicationHelper # for render_log
  include ActionController::Live

  rescue_from ActiveRecord::RecordInvalid, with: :invalid_job

  before_filter :authorize_deployer!, only: [:create]

  # XXX -- Need to verify viewers somehow for curl?
  skip_before_filter :login_users, only: [:stream]

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

    Thread.new { Deploy.new(job.id) }

    redirect_to project_job_path(project, job)
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.record.errors.full_messages.join("<br />").html_safe
    redirect_to project_path(project)
  end

  def stream
    # Using puma, because Redis#subscribe blocks while
    # waiting for a message, we won't get an IOError
    # raised when the connection is closed on the client
    # side until a message is sent. So we have a heartbeat thread.
    heartbeat = Thread.new do
      begin
        while true
          response.stream.write("data:\n\n")
          sleep(3)
        end
      rescue IOError
        # Raised on stream close
        response.stream.close
      end
    end

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    Redis.subscriber.subscribe(params[:id]) do |on|
      on.message do |channel, message|
        data = JSON.dump(msg: render_log(message).to_s)
        response.stream.write("data: #{data}\n\n")
      end
    end
  rescue IOError
    # Raised on stream close
  ensure
    heartbeat.join
    response.stream.close
  end

  def show
  end

  def update
    if job_history.user_id == current_user.id
      Redis.publisher.set("#{job_history.channel}:input", message_params[:message])
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
end
