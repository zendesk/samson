# frozen_string_literal: true

module SamsonKubernetes
  class Engine < Rails::Engine
    initializer "refinery.assets.precompile" do |app|
      app.config.assets.precompile.append %w[kubernetes/icon.png]
    end
  end
end

Samson::Hooks.view :project_tabs_view, 'samson_kubernetes/project_tab'
Samson::Hooks.view :admin_menu, 'samson_kubernetes/admin_menu'
Samson::Hooks.view :stage_form, "samson_kubernetes/stage_form"
Samson::Hooks.view :stage_show, "samson_kubernetes/stage_show"
Samson::Hooks.view :deploy_tab_nav, "samson_kubernetes/deploy_tab_nav"
Samson::Hooks.view :deploy_tab_body, "samson_kubernetes/deploy_tab_body"
Samson::Hooks.view :deploy_form, "samson_kubernetes/deploy_form"
Samson::Hooks.view :deploy_group_show, "samson_kubernetes/deploy_group_show"
Samson::Hooks.view :deploy_group_form, "samson_kubernetes/deploy_group_form"
Samson::Hooks.view :deploy_group_table_header, "samson_kubernetes/deploy_group_table_header"
Samson::Hooks.view :deploy_group_table_cell, "samson_kubernetes/deploy_group_table_cell"
Samson::Hooks.view :build_new, "samson_kubernetes/build_new"

Samson::Hooks.callback :deploy_group_permitted_params do
  { cluster_deploy_group_attributes: [:kubernetes_cluster_id, :namespace] }
end
Samson::Hooks.callback(:stage_permitted_params) { :kubernetes }
Samson::Hooks.callback(:deploy_permitted_params) { [:kubernetes_rollback, :kubernetes_reuse_build] }
Samson::Hooks.callback(:build_permitted_params) { :kubernetes_job }
