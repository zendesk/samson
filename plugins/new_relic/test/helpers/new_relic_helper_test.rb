require_relative '../test_helper'

SingleCov.covered!

describe NewRelicHelper do
  describe "#newrelic_enabled_for_deploy?" do
    before do
      @deploy = deploys(:succeeded_test)
      @deploy.stage.new_relic_applications.build
    end

    before { silence_warnings { SamsonNewRelic::Api::KEY = '123'.freeze } }
    after { silence_warnings { SamsonNewRelic::Api::KEY = nil } }

    it "is true" do
      assert newrelic_enabled_for_deploy?
    end

    it "is false when now applications are configured" do
      @deploy.stage.new_relic_applications.clear
      refute newrelic_enabled_for_deploy?
    end

    it "is false when api is not configured" do
      silence_warnings { SamsonNewRelic::Api::KEY = nil }
      refute newrelic_enabled_for_deploy?
    end
  end
end
