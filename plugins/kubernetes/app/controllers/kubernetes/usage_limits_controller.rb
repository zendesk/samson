# frozen_string_literal: true
class Kubernetes::UsageLimitsController < ResourceController
  ALL = 'all'

  before_action :authorize_admin!, except: [:show, :index]
  before_action :set_resource, only: [:show, :edit, :update, :destroy, :new, :create]

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
    @kubernetes_usage_limits = limits.sort_by do |l|
      [
        l.project&.name || '',
        @env_deploy_group_array.index { |_, type_and_id| type_and_id == l.scope_type_and_id } || 999
      ]
    end
  end

  private

  def resource_params
    super.permit(
      :project_id, :scope_type_and_id, :cpu, :memory, :comment
    )
  end
end
