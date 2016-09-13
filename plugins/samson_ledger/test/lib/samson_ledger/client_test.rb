# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe 'SamsonLedger::Client' do
  let(:deploy) { Deploy.first }

  before do
    @event_sent = stub_request(:post, "https://foo.bar/api/v1/events")
  end

  with_env(LEDGER_BASE_URL: 'https://foo.bar', LEDGER_TOKEN: "sometoken")

  describe ".plugin_enabled?" do
    it "is enabled" do
      assert SamsonLedger::Client.plugin_enabled?
    end

    it "is not enabled without token" do
      ENV.delete("LEDGER_TOKEN")
      refute SamsonLedger::Client.plugin_enabled?
    end

    it "is not enabled without base_url" do
      ENV.delete("LEDGER_BASE_URL")
      refute SamsonLedger::Client.plugin_enabled?
    end
  end

  describe ".post_deployment" do
    it "posts an event with a valid client" do
      SamsonLedger::Client.post_deployment(deploy)
      assert_requested(@event_sent)
    end
  end

  describe ".post_deployment" do
    before do
      stub_request(:post, "https://foo.bar/api/v1/events").
        to_return(status: 401)
    end

    it "rejects our token" do
      results = SamsonLedger::Client.post_deployment(deploy)
      results.status.to_i.must_equal(401)
    end
  end
end
