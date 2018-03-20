# frozen_string_literal: true

module SamsonRollbarDashboards
  class Engine < Rails::Engine
  end

  Samson::Hooks.view :project_form, "samson_rollbar_dashboards/fields"

  Samson::Hooks.callback :project_permitted_params do
    {
      rollbar_dashboards_settings_attributes: [
        :id,
        :base_url,
        :read_token,
        :time_zone,
        :_destroy
      ]
    }
  end
end
