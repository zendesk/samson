class StreamsController < ApplicationController
  newrelic_ignore if respond_to?(:newrelic_ignore)

  include ActionController::Live
  include ApplicationHelper

  def show
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    job = Job.find(params[:deploy_id])
    execution = JobExecution.find_by_id(job.id)

    streamer = EventStreamer.new(response.stream) do |event, data|
      case event
      when :viewers
        viewers = data.uniq.reject {|user| user == current_user}
        viewers.to_json(only: [:id, :name])
      when :finished
        execution.viewers.delete(current_user) if execution

        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.verify!

          job.reload

          @project = job.project
          @deploy = job.deploy
        end

        JSON.dump(html: render_to_string(partial: 'deploys/header', formats: :html))
      else
        JSON.dump(msg: render_log(data))
      end
    end

    if job.active? && execution
      execution.viewers.push(current_user)
      ActiveRecord::Base.clear_active_connections!
      streamer.start(execution.output)
    else
      streamer.finished
    end
  end
end
