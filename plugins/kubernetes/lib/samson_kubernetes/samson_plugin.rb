require_relative 'hash_kuber_selector'
require 'celluloid/current'

module SamsonKubernetes
  class Engine < Rails::Engine
    initializer "refinery.assets.precompile" do |app|
      app.config.assets.precompile.append %w(kubernetes/icon.png kubernetes/icon.svg)
    end
  end
end

Samson::Hooks.view :project_tabs_view, 'samson_kubernetes/project_tab'
Samson::Hooks.view :admin_menu, 'samson_kubernetes/admin_menu'
Samson::Hooks.view :stage_form, "samson_kubernetes/stage_form"
Samson::Hooks.view :stage_show, "samson_kubernetes/stage_show"

Samson::Hooks.callback :deploy_group_permitted_params do
  { cluster_deploy_group_attributes: [:kubernetes_cluster_id, :namespace] }
end

Samson::Hooks.callback :stage_permitted_params do
  :kubernetes
end

Samson::Hooks.callback :edit_deploy_group do |deploy_group|
  deploy_group.build_cluster_deploy_group unless deploy_group.cluster_deploy_group
end
