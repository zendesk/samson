class StreamsController < ApplicationController
  newrelic_ignore if respond_to?(:newrelic_ignore)

  include ActionController::Live
  include ApplicationHelper

  def show
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    @job = Job.find(params[:deploy_id])
    @execution = JobExecution.find_by_id(@job.id)

    streamer = EventStreamer.new(response.stream, &method(:event_handler))

    return response.stream.close unless @job.active? && @execution

    Rails.logger.info("Opening stream for #{response.stream.object_id}")
    @execution.viewers.push(current_user)
    ActiveRecord::Base.clear_active_connections!
    streamer.start(@execution.output)
  end

  private

  def event_handler(event, data)
    case event
    when :viewers
      viewers = data.uniq.reject {|user| user == current_user}
      viewers.to_json(only: [:id, :name])
    when :finished
      finished_response
    else
      JSON.dump(msg: render_log(data))
    end
  end

  def finished_response
    @execution.viewers.delete(current_user) if @execution

    ActiveRecord::Base.connection.verify!

    @job.reload

    @project = @job.project
    @deploy = @job.deploy

    ActiveRecord::Base.clear_active_connections!

    JSON.dump(html: render_to_body(partial: 'deploys/header', formats: :html))
  end
end
