class StreamsController < ApplicationController
  newrelic_ignore if respond_to?(:newrelic_ignore)

  include ActionController::Live
  include ApplicationHelper
  include DeploysHelper
  include JobsHelper

  def show
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    @job = Job.find(params[:id])
    @execution = JobExecution.find_by_id(@job.id)

    return response.stream.close unless @job.active? && @execution

    @execution.viewers.push(current_user)

    ActiveRecord::Base.clear_active_connections!

    EventStreamer.new(response.stream, &method(:event_handler)).
      start(@execution.output)
  end

  private

  def event_handler(event, data)
    case event
    when :started, :finished
      status_response(event)
    when :viewers
      viewers = data.uniq.reject {|user| user == current_user}
      viewers.to_json(only: [:id, :name])
    else
      JSON.dump(msg: render_log(data))
    end
  end

  def status_response(event)
    @execution.viewers.delete(current_user) if event == :finished

    # Need to reload data, as background thread updated the records on a separate DB connection,
    # and .reload() doesn't bypass QueryCache'ing.
    ActiveRecord::Base.uncached do
      @job.reload
      @project = @job.project
      @deploy = @job.deploy
    end

    if @deploy
      params = {
        title: deploy_page_title,
        html: render_to_body(partial: 'deploys/header', formats: :html)
      }
      params[:notification] = deploy_notification if event == :finished
      JSON.dump(params)
    else
      JSON.dump(
        title: job_page_title,
        html: render_to_body(partial: 'jobs/header', formats: :html)
      )
    end
  end
end
