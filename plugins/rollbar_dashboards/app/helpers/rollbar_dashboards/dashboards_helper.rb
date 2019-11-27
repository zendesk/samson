# frozen_string_literal: true

module RollbarDashboards
  module DashboardsHelper
    ROLLBAR_DASHBOARD_HEIGHT = 18 # em

    def rollbar_dashboard_placeholder_size(settings)
      settings.size * ROLLBAR_DASHBOARD_HEIGHT
    end

    # replaced by responsive_load.js.erb
    def rollbar_lazy_load_dashboard_container(item_path, settings)
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

    def rollbar_item_link(item_title, item_id, dashboard_setting)
      url = dashboard_setting.items_url
      url ? link_to(item_title, "#{url}/#{item_id}") : item_title
    end
  end
end
