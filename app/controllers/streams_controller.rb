class StreamsController < ApplicationController
  newrelic_ignore if respond_to?(:newrelic_ignore)

  include ActionController::Live
  include ApplicationHelper

  def show
    ActiveRecord::Base.clear_active_connections!

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    job = Job.find(params[:deploy_id])
    execution = JobExecution.find_by_id(job.id)
    streamer = EventStreamer.new(current_user, execution, response.stream) do
      job.reload

      @project = job.project
      @deploy = job.deploy

      JSON.dump(html: render_to_string(partial: 'deploys/header', formats: :html))
    end

    if job.active? && execution
      streamer.start(execution.output) do |event, data|
        if event == :viewers
          data.uniq.to_json(only: [:id, :name])
        else
          JSON.dump(msg: render_log(data))
        end
      end
    else
      streamer.finished
    end
  end
end
