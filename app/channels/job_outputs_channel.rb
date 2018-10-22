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

    def payload(event, data)
      case event
      when :started, :finished
        status_response(event)
      when :viewers
        data.to_a.uniq.as_json(only: [:id, :name])
      else
        render_log(data)
      end
    end

    private

    def status_response(event)
      # Need to reload data, as background thread updated the records on a separate DB connection
      # NOTE: might need an ActiveRecord::Base.uncached
      @job = Job.find(@job.id)
      @project = @job.project
      @deploy = @job.deploy

      if @deploy
        data = {title: deploy_page_title}

        if event == :finished
          data[:notification] = deploy_notification
          data[:favicon_path] = ApplicationController.helpers.deploy_favicon_path(@deploy)
        end

        data
      else
        {title: job_page_title}
      end
    end
  end

  # When a user subscribes send them all old messages and new messages,
  # each user ends up with their own channel instead of using a broadcast,
  # some kind of buffered broadcast channel would be ideal
  def subscribed
    id = params.fetch(:id)
    if execution = JobQueue.find_by_id(id)
      execution.viewers.push current_user
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          builder = EventBuilder.new(execution.job)
          execution.output.each do |event, data|
            transmit event: event, data: builder.payload(event, data)
          end
          # TODO: disconnect all listeners so they close their sockets ?
          # then replace the reloaded/finished/waitUntilEnabled stuff with that
        end
      end
    else # job has already stopped ... send fake output (reproduce by deploying a bad ref)
      job = Job.find(id)
      builder = EventBuilder.new(job)
      transmit event: :started, data: builder.payload(:started, nil)
      job.output.each_line do |line|
        transmit event: :message, data: builder.payload(:message, line)
      end
      transmit event: :finished, data: builder.payload(:finished, nil)
    end
  end

  def unsubscribed
    stop_all_streams
    if execution = JobQueue.find_by_id(params.fetch(:id))
      execution.viewers.delete current_user
    end
  end
end
