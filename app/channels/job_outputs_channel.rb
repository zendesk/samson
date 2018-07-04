# frozen_string_literal: true
class JobOutputsChannel < ActionCable::Channel::Base
  # pretends to be a controller to reuse partials and helpers
  class EventBuilder
    include ApplicationHelper
    include DeploysHelper
    include JobsHelper

    def initialize(job)
      @job = job
    end

    private

    def payload(data, event)
      case event
      when :started, :finished
        status_response(event)
      when :viewer
        data.to_a.uniq.as_json(only: [:id, :name])
      else
        render_log(data)
      end
    end

    def status_response(event)
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
          data[:favicon_path] = ApplicationController.helpers.deploy_favicon_path(@deploy)
        end

        data
      else
        {
          title: job_page_title,
          html: render_to_body(partial: 'jobs/header', formats: :html)
        }
      end
    end

    def render_to_body(args)
      ApplicationController.renderer.render_to_body(args)
    end
  end

  def self.stream(job, output)
    Thread.new do
      builder = EventBuilder.new(job)
      output.each do |data, event|
        ActionCable.server.broadcast "#{name}/#{job.id}", builder.payload(data, event)
      end
      # TODO: unsubscribe all ?
    end
  end

  def unsubscribe
    # TODO: remove current_user as viewer
  end

  def subscribed
    # TODO: add current_user as viewer
    stream_from "#{self.class.name}/#{params.fetch(:id)}"
  end
end
