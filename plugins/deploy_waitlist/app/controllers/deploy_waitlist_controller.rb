class DeployWaitlistController < ApplicationController
  before_action :timestamp_queue
  after_action :save_queue


  def add
    current_waitlist << { email: deployer, added: now }
    redirect_to project_stage_path(project, stage)
  end

  def remove
    index = deployer.to_i
    current_waitlist.delete_at(index)
    metadata[:head_since] = now if (index == 0)
    redirect_to project_stage_path(project, stage)
  end

  def up

  end

  def down

  end

  private

  def now
    Time.now.utc
  end

  def timestamp_queue
    metadata[:created_at] ||= now
  end

  def save_queue
    metadata[:last_updated] = now
    Rails.cache.write("deploy_waitlist", current_waitlist)
    Rails.cache.write("deploy_waitlist.metadata", metadata)
  end

  def current_waitlist
    @waitlist ||= Rails.cache.read("deploy_waitlist") || []
  end

  def metadata
    @metadata ||= Rails.cache.read("deploy_waitlist.metadata") || {}
  end

  def queue_action
    params[:queue_action]
  end

  def deployer
    params[:deployer]
  end

  def stage
    Stage.find_by_name(params[:stage])
  end

  def project
    Project.find_by_name(params[:project])
  end
end
