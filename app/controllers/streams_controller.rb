class StreamsController < ApplicationController
  include ActionController::Live
  include ApplicationHelper

  def show
    ActiveRecord::Base.connection_pool.release_connection

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    # Heartbeat thread until puma/puma#389 is solved
    @heartbeat = Thread.new do
      begin
        while true
          response.stream.write("data: \n\n")
          sleep(5) # Timeout of 5 seconds
        end
      rescue IOError
        response.stream.close
      end
    end

    if job.active? && (execution = JobExecution.find_by_id(job.id))
      execution.output.each_message do |message|
        msg = JSON.dump(msg: render_log(message).to_s)
        response.stream.write("data: #{msg}\n\n")
      end
    end
  rescue IOError
    # Raised on stream close
  ensure
    @heartbeat.try(:kill)
    response.stream.close
  end

  protected

  def job
    @job ||= Job.find(params[:id])
  end
end
