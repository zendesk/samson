require_relative '../test_helper'

SingleCov.covered!

describe FlowdockHelper do
  describe "#default_flowdock_message" do
    it "renders" do
      message = default_flowdock_message deploys(:succeeded_test)
      message.must_include ":pray: @team Super Admin is requesting approval to deploy Project **staging** to production"
    end
  end
end
