# frozen_string_literal: true
class Admin::Kubernetes::UsageLimitsController < ApplicationController
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
    @usage_limits = ::Kubernetes::UsageLimit.all # TODO: smarter sorting like env vars
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
      :project_id, :scope_type_and_id, :replicas, :cpu, :memory
    )
  end
end
