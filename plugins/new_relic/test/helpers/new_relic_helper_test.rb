require_relative '../test_helper'

SingleCov.covered!

describe NewRelicHelper do
  describe "#newrelic_enabled_for_deploy?" do
    before do
      @deploy = deploys(:succeeded_test)
      @deploy.stage.new_relic_applications.build
    end

    around do |test|
      begin
        old, NewRelicApi.api_key = NewRelicApi.api_key, 'FAKE-KEY'
        test.call
      ensure
        NewRelicApi.api_key = old
      end
    end

    it "is true" do
      assert newrelic_enabled_for_deploy?
    end

    it "is false when now applications are configured" do
      @deploy.stage.new_relic_applications.clear
      refute newrelic_enabled_for_deploy?
    end

    it "is false when api is not configured" do
      NewRelicApi.api_key = nil
      refute newrelic_enabled_for_deploy?
    end
  end
end
