# frozen_string_literal: true

module SamsonRollbarDashboards
  class Engine < Rails::Engine
    config.assets.precompile.append ['rollbar_dashboards/icon.png', 'rollbar_dashboards/deploy_dashboard.js']
  end

  Samson::Hooks.view :project_view, 'samson_rollbar_dashboards'
  Samson::Hooks.view :project_form, 'samson_rollbar_dashboards'
  Samson::Hooks.view :deploy_show_view, 'samson_rollbar_dashboards'

  Samson::Hooks.callback :project_permitted_params do
    {
      rollbar_dashboards_settings_attributes: [
        :id,
        :base_url,
        :read_token,
        :account_and_project_name,
        :_destroy
      ]
    }
  end
end
