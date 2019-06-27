# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe RollbarWebhook do
  let(:webhook) do
    RollbarWebhook.new(
      stage: stages(:test_staging),
      access_token: "fsdfsf",
      environment: "production",
      webhook_url: "https://foo.com"
    )
  end

  describe "validations" do
    it "is valid" do
      assert_valid webhook
    end

    it "is valid with resolvable access_token" do
      create_secret "global/global/global/foo"
      webhook.access_token = "secret://foo"
      assert_valid webhook
    end

    it "is invalid without access token" do
      webhook.access_token = ""
      refute_valid webhook
      webhook.errors.full_messages.must_equal ["Access token can't be blank"]
    end

    it "is invalid with unresolvable access token" do
      webhook.access_token = "secret://foo"
      refute_valid webhook
      webhook.errors.full_messages.must_equal(
        ["Access token unable to resolve secret (is it global/<project>/global ? / does it exist ?)"]
      )
    end
  end
end
