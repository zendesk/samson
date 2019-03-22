# frozen_string_literal: true

module RollbarDashboards
  class Setting < ActiveRecord::Base
    self.table_name = 'rollbar_dashboards_settings'

    belongs_to :project, inverse_of: :rollbar_dashboards_settings

    validates :base_url, :read_token, presence: true
  end
end
