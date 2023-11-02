require "spec_helper"

module Vault
  describe Sys do
    subject { vault_test_client.sys }

    describe "#seal_status" do
      it "returns the seal status" do
        result = subject.seal_status
        expect(result).to be_a(SealStatus)
        expect(result.sealed?).to be(false)
        expect(result.t).to eq(1)
        expect(result.n).to eq(1)
        expect(result.progress).to eq(0)
      end
    end

    describe "#seal/#unseal" do
      it "seals and unseals the vault" do
        subject.seal
        expect(subject.seal_status.sealed?).to be(true)
        subject.unseal(RSpec::VaultServer.unseal_token)
        expect(subject.seal_status.sealed?).to be(false)
      end
    end
  end
end
