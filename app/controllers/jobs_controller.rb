# frozen_string_literal: true
class JobsController < ApplicationController
  include CurrentProject

  skip_before_action :require_project, only: [:enabled]

  before_action :authorize_project_deployer!, only: [:destroy]
  before_action :find_job, only: [:show, :destroy]

  def show
    respond_to do |format|
      format.html
      format.text do
        datetime = @job.updated_at.strftime("%Y%m%d_%H%M%Z")
        send_data @job.output,
          type: 'text/plain',
          filename: "#{@project.permalink}-#{@job.id}-#{datetime}.log"
      end
    end
  end

  def enabled
    if JobExecution.enabled
      head :no_content
    else
      head :accepted
    end
  end

  def destroy
    if @job.can_be_stopped_by?(current_user)
      @job.stop!
      flash[:notice] = "Cancelled!"
    else
      flash[:error] = "You are not allowed to stop this job."
    end

    redirect_back_or [@project, @job]
  end

  private

  def find_job
    @job = current_project.jobs.find(params[:id])
  end
end
