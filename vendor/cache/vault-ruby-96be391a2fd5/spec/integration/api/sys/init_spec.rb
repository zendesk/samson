require "spec_helper"

module Vault
  describe Sys do
    subject { vault_test_client.sys }

    describe "#init_status" do
      it "returns the status" do
        result = subject.init_status
        expect(result).to be_a(InitStatus)
        expect(result.initialized?).to be(true)
      end
    end

    describe "#init" do
      it "initializes a new vault server" do
        skip "Cannot initialize a running vault server"
      end
    end
  end
end
