# frozen_string_literal: true
class StreamsController < ApplicationController
  newrelic_ignore if respond_to?(:newrelic_ignore)

  include ActionController::Live
  include ApplicationHelper
  include DeploysHelper
  include JobsHelper

  def show
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Access-Control-Allow-Origin'] = Rails.application.config.samson.uri.to_s
    response.headers['Access-Control-Allow-Credentials'] = true

    @job = Job.find(params[:id])
    @execution = JobQueue.find_by_id(@job.id)

    event_streamer = EventStreamer.new(response.stream, &method(:event_handler))

    if @job.active? && @execution
      @execution.viewers.push(current_user)

      ActiveRecord::Base.clear_active_connections!

      event_streamer.start(@execution.output)
    else
      event_streamer.start(@job.output)
    end
  end

  private

  def event_handler(event, data)
    case event
    when :started, :finished
      status_response(event)
    when :viewers # show who else is viewing
      viewers = data.to_a.uniq.reject { |user| user == current_user }
      viewers.to_json(only: [:id, :name])
    else
      JSON.dump(msg: render_log(data))
    end
  end

  def status_response(event)
    @execution&.viewers&.delete(current_user) if event == :finished

    # Need to reload data, as background thread updated the records on a separate DB connection,
    # and .reload() doesn't bypass QueryCache'ing.
    ActiveRecord::Base.uncached do
      @job.reload
      @project = @job.project
      @deploy = @job.deploy
    end

    if @deploy
      data = {
        title: deploy_page_title,
        html: render_to_body(partial: 'deploys/header', formats: :html)
      }

      if event == :finished
        data[:notification] = deploy_notification
        data[:favicon_path] = self.class.helpers.deploy_favicon_path(@deploy)
      end

      JSON.dump(data)
    else
      JSON.dump(
        title: job_page_title,
        html: render_to_body(partial: 'jobs/header', formats: :html)
      )
    end
  end
end
