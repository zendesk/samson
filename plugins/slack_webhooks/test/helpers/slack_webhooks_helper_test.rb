require_relative '../test_helper'

SingleCov.covered!

describe SlackWebhooksHelper do
  describe "#default_slack_message" do
    it "renders" do
      message = default_slack_message deploys(:succeeded_test)
      message.must_include ":pray: @here _Super Admin_ is requesting approval to deploy Project *staging* to Staging.\nReview this deploy: http://test.host/projects/foo/deploys/178003093"
    end
  end
end
