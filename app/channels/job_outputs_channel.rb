# frozen_string_literal: true
class JobOutputsChannel < ActionCable::Channel::Base
  MAX_WAIT = 1200 # max seconds to wait for job to start when streaming
  WAIT_DURATION = 5 # seconds between re-checking

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

    @thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        (MAX_WAIT / WAIT_DURATION).times do
          break if @unsubscribed

          # running
          execution = JobQueue.find_by_id(id)
          break stream_execution(execution) if execution

          # cancelled or we missed it running
          job = Job.find(id)
          break stream_finished_output(job) if job.finished?

          # pending
          sleep WAIT_DURATION
        end
      end
    end
  end

  def unsubscribed
    @unsubscribed = true
    if execution = JobQueue.find_by_id(params.fetch(:id))
      execution.viewers.delete current_user
    end
  end

  private

  def stream_execution(execution)
    execution.viewers.push current_user
    builder = EventBuilder.new(execution.job)
    execution.output.each do |event, data|
      transmit({event: event, data: builder.payload(event, data)})
    end
  end

  # send fake output (reproduce by deploying a bad ref)
  def stream_finished_output(job)
    builder = EventBuilder.new(job)
    transmit({event: :started, data: builder.payload(:started, nil)})
    job.output.each_line do |line|
      transmit({event: :message, data: builder.payload(:message, line)})
    end
    transmit({event: :finished, data: builder.payload(:finished, nil)})
  end
end
