# frozen_string_literal: true
class Api::DeploysController < Api::BaseController
  skip_before_action :require_project, only: [:active_count]
  before_action :validate_filter, only: :index

  def index
    render json: paginate(Deploy.joins(:job).where(search_params))
  end

  def active_count
    render json: Deploy.active.count
  end

  protected

  def job_filter
    params[:filter]
  end

  def search_params
    if stage_id = params[:stage_id]
      search_params = {deploys: {stage_id: stage_id}}
    elsif project_id = params[:project_id]
      stage_ids = Project.find(project_id).stages.pluck(:id)
      search_params = {deploys: {stage_id: stage_ids}}
    end

    search_params[:jobs] = {status: job_filter} if job_filter

    search_params
  end

  def validate_filter
    return unless job_filter
    unless Job.valid_status?(job_filter)
      render json: { error: "Filter is not valid. Please use " + Job::VALID_STATUSES.join(", ") }, status: :bad_request
    end
  end
end
