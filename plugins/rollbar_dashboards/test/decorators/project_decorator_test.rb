# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Project do
  let(:project) { projects(:test) }

  describe "assigning rollbar attributes" do
    before { RollbarDashboards::Setting.destroy_all }

    it "assigns rollbar dashboard attributes" do
      project.attributes = {
        rollbar_dashboards_settings_attributes: {0 => {read_token: '123', base_url: 'https://foobar.org'}}
      }
      project.rollbar_dashboards_settings.size.must_equal 1
    end

    it "does not assign without url and token" do
      project.attributes = {rollbar_dashboards_settings_attributes: {0 => {base_url: '', read_token: ''}}}
      project.rollbar_dashboards_settings.size.must_equal 0
    end
  end
end
