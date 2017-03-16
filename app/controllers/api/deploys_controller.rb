# frozen_string_literal: true
class Api::DeploysController < Api::BaseController
  skip_before_action :require_project, only: [:active_count]
  before_action :validate_filter, only: :index

  def index
    render json: paginate(deploy_scope)
  end

  def show
    render json: Deploy.find(params.require(:id))
  end

  def active_count
    render json: Deploy.active.count
  end

  protected

  def job_filter
    params[:filter]
  end

  def deploy_scope
    scope = Deploy

    if stage_id = params[:stage_id]
      scope = scope.where(stage_id: stage_id)
    elsif project_id = params[:project_id]
      scope = scope.where(project_id: project_id)
    end

    scope = scope.joins(:job).where(jobs: {status: job_filter}) if job_filter

    scope
  end

  def validate_filter
    return unless job_filter
    unless Job.valid_status?(job_filter)
      render json: { error: "Filter is not valid. Please use " + Job::VALID_STATUSES.join(", ") }, status: :bad_request
    end
  end
end
