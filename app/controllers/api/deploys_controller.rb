# frozen_string_literal: true
class Api::DeploysController < Api::BaseController
  include CurrentProject

  skip_before_action :require_project, only: [:active_count]

  def index
    scope = current_project.try(:deploys) || Deploy
    @deploys = paginate(params[:ids].present? ? [scope.find(params[:ids])].flatten : scope)
    render json: @deploys
  end

  def active_count
    render json: Deploy.active.count
  end
end
