# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe "the samson_ledger plugin callback" do
  let(:deploy) { Deploy.first }

  before do
    stub_request(:post, "https://foo.bar/api/v1/events")
  end

  with_env(LEDGER_TOKEN: "sometoken", LEDGER_BASE_URL: "https://foo.bar")

  let(:deploy) { Deploy.first }

  it "successfully fires the before_deploy" do
    SamsonLedger::Client.expects(:post_event)
    Samson::Hooks.fire(:before_deploy, deploy, stub(output: nil))
  end

  it "successfully fires the after_deploy" do
    SamsonLedger::Client.expects(:post_event)
    Samson::Hooks.fire(:after_deploy, deploy, stub(output: nil))
  end

  it "fails to fires the after_deploy" do
    ENV.delete("LEDGER_TOKEN")
    SamsonLedger::Client.expects(:post_event).never
    Samson::Hooks.fire(:after_deploy, deploy, stub(output: nil))
  end
end
