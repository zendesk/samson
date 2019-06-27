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

    def item_link(item_title, item_id, dashboard_setting)
      if account_and_project_name = dashboard_setting.account_and_project_name.presence
        # Removes path and handles https://api.rollbar.com cases
        domain = URI.join(dashboard_setting.base_url, '/').to_s.sub('://api.', '://')

        item_url = "#{domain}#{account_and_project_name}/items/#{item_id}"
        link_to item_title, item_url
      else
        item_title
      end
    end
  end
end
