class DeployWaitlistController < ApplicationController

  def add
    current_waitlist.deployers += [{ email: deployer, added: now }]
    redirect_to project_stage_path(project, stage)
  end

  def remove
    current_waitlist.remove(deployer.to_i)
    redirect_to project_stage_path(project, stage)
  end

  private

  def now
    Time.now.utc
  end

  def save_queue
    Rails.cache.write(key, current_waitlist)
    Rails.cache.write(metadata_key, metadata)
  end

  def current_waitlist
    @waitlist ||= Waitlist.new(project.id, stage.id)
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
