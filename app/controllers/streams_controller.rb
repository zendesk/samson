class StreamsController < ApplicationController
  include ActionController::Live
  include ApplicationHelper

  def show
    ActiveRecord::Base.connection_pool.release_connection

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    job = Job.find(params[:id])

    if job.active? && (execution = JobExecution.find_by_id(job.id))
      output = execution.output.lazy.map {|message| render_log(message) }
      OutputStreamer.start(output, response.stream)
    else
      response.stream.close
    end
  end
end
