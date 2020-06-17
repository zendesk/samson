# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutboundWebhookStage do
  let(:stage) { stages(:test_staging) }
  let(:outbound_webhook) { OutboundWebhook.create!(url: 'http://dsfsf.com', auth_type: "None") }
  let(:ows) { OutboundWebhookStage.new(stage: stage, outbound_webhook: outbound_webhook) }

  describe "validations" do
    it "is valid" do
      assert_valid ows
    end

    it "is valid when stage has a different webhook" do
      OutboundWebhook.create!(stages: [stage], url: 'http://dsfsf.com', auth_type: "None")
      assert_valid ows
    end

    it "is not valid when stage already has the webhook" do
      OutboundWebhookStage.create!(stage: stage, outbound_webhook: outbound_webhook)
      refute_valid ows
    end
  end
end
