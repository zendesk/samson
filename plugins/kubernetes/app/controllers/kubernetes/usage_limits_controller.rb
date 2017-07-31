# frozen_string_literal: true
class Kubernetes::UsageLimitsController < ApplicationController
  before_action :authorize_admin!
  before_action :find_usage_limit, only: [:show, :update, :destroy]

  def new
    @usage_limit = ::Kubernetes::UsageLimit.new
    render :show
  end

  def create
    @usage_limit = ::Kubernetes::UsageLimit.new(usage_limit_params)
    if @usage_limit.save
      redirect_to({action: :index}, notice: "Saved!")
    else
      render :show
    end
  end

  def index
    limits = ::Kubernetes::UsageLimit.all
    if project_id = params.dig(:search, :project_id).presence
      limits = limits.where(project_id: project_id)
    end
    if scope_type_and_id = params.dig(:search, :scope_type_and_id).presence
      scope_type, scope_id = GroupScope.split(scope_type_and_id)
      limits = limits.where(scope_type: scope_type, scope_id: scope_id)
    end
    @usage_limits = limits.sort_by { |l| [l.project&.name || '', l.scope&.name || ''] }
  end

  def show
  end

  def update
    @usage_limit.assign_attributes(usage_limit_params)
    if @usage_limit.save
      redirect_to({action: :index}, notice: "Saved!")
    else
      render :show
    end
  end

  def destroy
    @usage_limit.destroy
    redirect_to({action: :index}, notice: "Destroyed!")
  end

  private

  def find_usage_limit
    @usage_limit = ::Kubernetes::UsageLimit.find(params[:id])
  end

  def usage_limit_params
    params.require(:kubernetes_usage_limit).permit(
      :project_id, :scope_type_and_id, :cpu, :memory
    )
  end
end
