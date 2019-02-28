# frozen_string_literal: true
class JobsController < ApplicationController
  include CurrentProject

  skip_before_action :require_project, only: [:enabled]

  before_action :authorize_project_deployer!, except: [:index, :show, :enabled]
  before_action :find_job, only: [:show, :destroy]

  def index
    @pagy, @jobs = pagy(@project.jobs.non_deploy, page: params[:page], items: 15)
  end

  def show
    respond_to do |format|
      format.html do
        if params[:header]
          @deploy = @job.deploy
          partial = (@deploy ? 'deploys/header' : 'jobs/header')
          render partial: partial, layout: false
        end
      end
      format.text do
        datetime = @job.updated_at.strftime("%Y%m%d_%H%M%Z")
        send_data @job.output,
          type: 'text/plain',
          filename: "#{@project.permalink}-#{@job.id}-#{datetime}.log"
      end
    end
  end

  def enabled
    if JobQueue.enabled
      head :no_content
    else
      head :accepted
    end
  end

  def destroy
    @job.cancel(current_user)
    flash[:notice] = "Cancelled!"
    redirect_back fallback_location: [@project, @job]
  end

  private

  def find_job
    @job = current_project.jobs.find(params[:id])
  end
end
