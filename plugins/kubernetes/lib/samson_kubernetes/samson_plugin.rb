require_relative 'hash_kuber_selector'

module SamsonKubernetes
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :project_tabs_view, 'kubernetes_project/project_tab'
Samson::Hooks.view :admin_menu, 'kubernetes_project/admin_menu'
