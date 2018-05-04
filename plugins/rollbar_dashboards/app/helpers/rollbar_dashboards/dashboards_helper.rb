# frozen_string_literal: true

module RollbarDashboards
  module DashboardsHelper
    DASHBOARD_HEIGHT = 22 # em

    def rollbar_dashboard_placeholder_size(settings)
      settings.size * DASHBOARD_HEIGHT
    end

    def rollbar_dashboard_container(item_path, settings)
      content_tag(
        :div,
        '',
        class: 'lazy-load dashboard-container',
        style: "min-height: #{rollbar_dashboard_placeholder_size(settings)}em;",
        data: {
          url: item_path,
          delay: 1000
        }
      )
    end
  end
end
