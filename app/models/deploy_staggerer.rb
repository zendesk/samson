# frozen_string_literal: true

class DeployStaggerer
  include Singleton

  STAGGER_INTERVAL = Integer(ENV['DEPLOY_STAGGER_INTERVAL'] || '0').seconds

  class << self
    delegate :process, :dequeue, :queued?, to: :instance
  end

  def process(job_execution, deploy)
    @lock.synchronize do
      if @queue.empty? && can_deploy?
        send_to_job_queue(job_execution, deploy)
      else
        enqueue(job_execution, deploy)
      end
    end
  end

  def dequeue
    @lock.synchronize do
      if @queue.present? && can_deploy?
        job_execution, deploy = @queue.shift
        send_to_job_queue(job_execution, deploy)
      end
    end
  end

  def queued?(id)
    @queue.any? { |(job_execution, _deploy)| job_execution.id == id }
  end

  private

  def enqueue(job_execution, deploy)
    @queue << [job_execution, deploy]
  end

  def can_deploy?
    STAGGER_INTERVAL == 0 || @last_deploy_started_at.nil? || Time.now - @last_deploy_started_at >= STAGGER_INTERVAL
  end

  def send_to_job_queue(job_execution, deploy)
    @last_deploy_started_at = Time.now
    JobQueue.perform_later(job_execution, queue: deploy.job_execution_queue_name)
  end

  def initialize
    @queue = []
    @lock = Mutex.new
  end
end
