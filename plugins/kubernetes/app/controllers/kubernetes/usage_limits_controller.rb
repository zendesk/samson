# frozen_string_literal: true
class Kubernetes::UsageLimitsController < ResourceController
  ALL = 'all'

  before_action :authorize_admin!, except: [:show, :index]
  before_action :set_resource, only: [:show, :update, :destroy, :new, :create]

  private

  def search_resources
    if project_id = params[:project_id]
      @project = Project.find_by_param!(project_id)
      @project.kubernetes_usage_limits
    else
      limits = ::Kubernetes::UsageLimit.all

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

      limits
    end
  end

  def resource_params
    super.permit(
      :project_id, :scope_type_and_id, :cpu, :memory, :comment
    )
  end
end
