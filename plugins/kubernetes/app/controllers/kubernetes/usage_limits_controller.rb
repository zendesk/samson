# frozen_string_literal: true
class Kubernetes::UsageLimitsController < ApplicationController
  ALL = 'all'

  before_action :authorize_admin!, except: [:show, :index]
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
    if project_id = params[:project_id]
      @project = Project.find_by_param!(project_id)
      limits = @project.kubernetes_usage_limits
    else
      limits = ::Kubernetes::UsageLimit.all
      @projects = limits.map(&:project).uniq.compact.sort_by(&:name)

      if project_id = params.dig(:search, :project_id).presence
        project_id = nil if project_id == ALL
        limits = limits.where(project_id: project_id)
      end

      if scope_type_and_id = params.dig(:search, :scope_type_and_id).presence
        if scope_type_and_id == ALL
          scope_type, scope_id = nil
        else
          scope_type, scope_id = GroupScope.split(scope_type_and_id)
        end
        limits = limits.where(scope_type: scope_type, scope_id: scope_id)
      end
    end

    @env_deploy_group_array = Environment.env_deploy_group_array(include_all: false)
    @usage_limits = limits.sort_by do |l|
      [
        l.project&.name || '',
        @env_deploy_group_array.index { |_, type_and_id| type_and_id == l.scope_type_and_id } || 999
      ]
    end
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
      :project_id, :scope_type_and_id, :cpu, :memory, :comment
    )
  end
end
