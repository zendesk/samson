class StreamsController < ApplicationController
  include ActionController::Live
  include ApplicationHelper

  def show
    ActiveRecord::Base.connection_pool.release_connection

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    # Heartbeat thread until puma/puma#389 is solved
    @heartbeat = Thread.new do
      running = true
      while running
        begin
          response.stream.write("data: \n\n")
        rescue IOError
          response.stream.close
          running = false
        end

        sleep(5) # Timeout of 5 seconds
      end
    end

    if job.active? && (execution = JobExecution.find_by_id(job.id))
      execution.output.subscribe do |subscriber|
        subscriber.on_message do |message|
          msg = JSON.dump(msg: render_log(message).to_s)
          response.stream.write("data: #{msg}\n\n")
        end

        subscriber.on_close { close_stream }
      end
    end
  rescue IOError
    # Raised on stream close
  ensure
    close_stream
  end

  protected

  def job
    @job ||= Job.find(params[:id])
  end

  def close_stream
    @heartbeat.try(:kill)
    response.stream.close
  end
end
