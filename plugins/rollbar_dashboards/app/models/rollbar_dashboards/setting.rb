# frozen_string_literal: true

module RollbarDashboards
  class Setting < ActiveRecord::Base
    self.table_name = 'rollbar_dashboards_settings'

    belongs_to :project, inverse_of: :rollbar_dashboards_settings

    validates :base_url, :read_token, presence: true
    validates :account_and_project_name, presence: true, if: :new_record? # TODO: backfill all and then always validate

    def items_url
      return unless account_and_project_name?
      domain = URI.join(base_url, '/').to_s.sub('://api.', '://') # Removes path and handle https://api.rollbar.com
      "#{domain}#{account_and_project_name}/items"
    end
  end
end
