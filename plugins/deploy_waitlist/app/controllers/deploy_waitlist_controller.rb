# frozen_string_literal: true
class DeployWaitlistController < ApplicationController
  def show
    respond_to do |format|
      format.html
      format.json { render json: current_waitlist.to_json }
    end
  end

  def add
    Rails.logger.warn("current_waitlist: #{current_waitlist.list}")
    current_waitlist.add(email: deployer, added: now)
    render json: current_waitlist.to_json
  end

  def remove
    current_waitlist.remove(deployer.to_i)
    render json: current_waitlist.to_json
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
