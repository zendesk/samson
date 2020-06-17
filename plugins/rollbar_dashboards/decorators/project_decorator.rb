# frozen_string_literal: true

Project.class_eval do
  has_many :rollbar_dashboards_settings, class_name: 'RollbarDashboards::Setting', dependent: :destroy

  accepts_nested_attributes_for :rollbar_dashboards_settings, allow_destroy: true, reject_if: ->(a) do
    a.fetch(:base_url).blank? && a.fetch(:read_token).blank?
  end
end
