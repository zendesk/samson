class StreamsController < ApplicationController
  include ActionController::Live
  include ApplicationHelper

  def show
    ActiveRecord::Base.connection_pool.release_connection

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    job = Job.find(params[:id])

    streamer = EventStreamer.new(response.stream)

    if job.active? && (execution = JobExecution.find_by_id(job.id))
      streamer.start(execution.output) {|line| render_log(line) }
    else
      streamer.finished
    end
  end
end
