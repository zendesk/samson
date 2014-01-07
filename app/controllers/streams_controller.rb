class StreamsController < ApplicationController
  include ActionController::Live
  include ApplicationHelper

  before_filter :find_job_execution

  def show
    ActiveRecord::Base.connection_pool.release_connection

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    # Heartbeat thread
    @job_execution.output.each_message do |message|
      msg = JSON.dump(msg: render_log(message).to_s)
      response.stream.write("data: #{msg}\n\n")
    end
  rescue IOError
    # Raised on stream close
  ensure
    response.stream.close
  end

  protected

  def find_job_execution
    @job_execution = JobExecution.find_by_id(params[:id])

    head :not_found if @job_execution.nil?
  end
end
