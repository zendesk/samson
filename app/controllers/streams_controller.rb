class StreamsController < ApplicationController
  include ActionController::Live
  include ApplicationHelper

  def show
    ActiveRecord::Base.connection_pool.release_connection

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    # Heartbeat thread
    deploy.output.each_message do |message|
      msg = JSON.dump(msg: render_log(message).to_s)
      response.stream.write("data: #{msg}\n\n")
    end
  rescue IOError
    # Raised on stream close
  ensure
    response.stream.close
  end

  protected

  def deploy
    @deploy ||= if (thread = Thread.main[:deploys][job_history.id])
      thread[:deploy]
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def job_history
    @job_history ||= JobHistory.find_by_channel!(params[:id])
  end
end
