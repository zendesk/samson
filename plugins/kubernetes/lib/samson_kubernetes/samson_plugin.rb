# frozen_string_literal: true

module SamsonKubernetes
  class Engine < Rails::Engine
    initializer "refinery.assets.precompile" do |app|
      app.config.assets.precompile.append %w[kubernetes/icon.png]
    end
  end

  NOT_A_404 = ->(e) { !e.is_a?(Kubeclient::ResourceNotFoundError) }

  API_RETRIES = 5

  # http errors and ssl errors are not handled uniformly, but we want to ignore/retry on both
  # see https://github.com/abonas/kubeclient/issues/240
  # using a method to avoid loading kubeclient on every boot ~0.1s
  def self.connection_errors
    [OpenSSL::SSL::SSLError, Kubeclient::HttpError, Errno::ECONNREFUSED, Errno::ECONNRESET].freeze
  end

  def self.retry_on_connection_errors(&block)
    Samson::Retry.with_retries connection_errors, API_RETRIES, only_if: NOT_A_404, wait_time: 0.1, &block
  end
end

Samson::Hooks.view :project_tabs_view, 'samson_kubernetes'
Samson::Hooks.view :project_form, "samson_kubernetes"
Samson::Hooks.view :manage_menu, 'samson_kubernetes'
Samson::Hooks.view :stage_form, "samson_kubernetes"
Samson::Hooks.view :stage_show, "samson_kubernetes"
Samson::Hooks.view :deploy_tab_nav, "samson_kubernetes"
Samson::Hooks.view :deploy_tab_body, "samson_kubernetes"
Samson::Hooks.view :deploy_form, "samson_kubernetes"
Samson::Hooks.view :deploy_group_show, "samson_kubernetes"
Samson::Hooks.view :deploy_group_form, "samson_kubernetes"
Samson::Hooks.view :deploy_group_table_header, "samson_kubernetes"
Samson::Hooks.view :deploy_group_table_cell, "samson_kubernetes"

Samson::Hooks.callback :deploy_group_permitted_params do
  {cluster_deploy_group_attributes: [:kubernetes_cluster_id, :namespace]}
end
Samson::Hooks.callback(:stage_permitted_params) do
  [
    :kubernetes,
    {kubernetes_stage_roles_attributes: [:kubernetes_role_id, :ignored, :_destroy, :id]}
  ]
end
Samson::Hooks.callback(:deploy_permitted_params) { [:kubernetes_rollback, :kubernetes_reuse_build] }
Samson::Hooks.callback(:project_permitted_params) { [:kubernetes_rollout_timeout] }
Samson::Hooks.callback(:link_parts_for_resource) do
  [
    "Kubernetes::Cluster",
    ->(cluster) { [cluster.name, cluster] }
  ]
end

Samson::Hooks.callback(:link_parts_for_resource) do
  [
    "Kubernetes::DeployGroupRole",
    ->(dgr) { ["#{dgr.project&.name} role #{dgr.kubernetes_role&.name} for #{dgr.deploy_group&.name}", dgr] }
  ]
end
Samson::Hooks.callback(:link_parts_for_resource) do
  [
    "Kubernetes::Role",
    ->(role) { ["#{role.project&.name} role #{role.name}", [role.project, role]] }
  ]
end
Samson::Hooks.callback(:link_parts_for_resource) do
  [
    "Kubernetes::UsageLimit",
    ->(limit) { ["Limit for #{limit.scope&.name} on #{limit.project&.name || "All"}", limit] }
  ]
end
Samson::Hooks.callback(:link_parts_for_resource) do
  [
    "Kubernetes::Namespace",
    ->(namespace) { [namespace.name, namespace] }
  ]
end

Samson::Hooks.callback(:deploy_group_includes) { :kubernetes_cluster }

Samson::Hooks.callback(:stage_clone) do |old_stage, new_stage|
  roles_to_copy = Kubernetes::DeployGroupRole.where(
    project: old_stage.project,
    deploy_group: old_stage.deploy_groups.last
  )

  new_stage.deploy_groups.each do |deploy_group|
    roles_to_copy.each do |dgr|
      Kubernetes::DeployGroupRole.create(
        dgr.attributes.
          except('id', 'created_at', 'updated_at').
          merge('deploy_group_id' => deploy_group.id)
      )
    end
  end
end
