class DeployWaitlistController < ApplicationController

  def add
    Rails.logger.warn("current_waitlist: #{current_waitlist.deployers}")
    current_waitlist.add({ email: deployer, added: now })
    redirect_to project_stage_path(project, stage)
  end

  def remove
    current_waitlist.remove(deployer.to_i)
    redirect_to project_stage_path(project, stage)
  end

  private

  def now
    Time.now
  end

  def current_waitlist
    @waitlist ||= Waitlist.new(project.id, stage.id)
  end

  def deployer
    params[:deployer]
  end

  def stage
    Stage.find params[:stage]
  end

  def project
    Project.find params[:project]
  end
end
