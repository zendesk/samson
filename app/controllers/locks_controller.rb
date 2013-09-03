class LocksController < ApplicationController
  before_filter :authorize_admin!
  helper_method :project

  def new
    @lock = project.job_locks.build
  end

  def create
    @lock = project.job_locks.create(lock_params)

    if @lock.persisted?
      redirect_to root_path
    else
      flash[:error] = lock_errors
      render :new
    end
  end

  def destroy
    project.job_locks.destroy(params[:id])
    redirect_to root_path
  end

  protected

  def project
    @project ||= Project.find(params[:project_id])
  end

  def lock_params
    params.require(:job_lock).
      permit(:environment, :expires_at)
  end

  def lock_errors
    [:environment, :expires_at].map do |key|
      @lock.errors.full_messages_for(key)
    end.flatten.join("<br />").html_safe
  end
end
