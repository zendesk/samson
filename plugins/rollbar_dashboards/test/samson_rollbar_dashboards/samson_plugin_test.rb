# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe SamsonRollbarDashboards do
  describe 'project_permitted_params_callback' do
    it 'adds rollbar_read_token to permitted params' do
      expected = [{ rollbar_dashboards_settings_attributes: [:id, :base_url, :read_token, :time_zone, :_destroy] }]
      Samson::Hooks.only_callbacks_for_plugin('rollbar_dashboards', :project_permitted_params) do
        Samson::Hooks.fire(:project_permitted_params).must_equal expected
      end
    end
  end
end
