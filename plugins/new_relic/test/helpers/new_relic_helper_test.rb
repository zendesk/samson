# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe NewRelicHelper do
  with_new_relic_plugin_enabled

  describe "#newrelic_enabled_for_deploy?" do
    before do
      @deploy = deploys(:succeeded_test)
      @deploy.stage.new_relic_applications.build
    end

    it "is true" do
      assert newrelic_enabled_for_deploy?
    end

    it "is false when now applications are configured" do
      @deploy.stage.new_relic_applications.clear
      refute newrelic_enabled_for_deploy?
    end

    it "is false when api is not configured" do
      silence_warnings { SamsonNewRelic::API_KEY = nil }
      refute newrelic_enabled_for_deploy?
    end
  end
end
