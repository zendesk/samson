require "spec_helper"

module Vault
  describe Sys do
    subject { vault_test_client.sys }

    describe "#auths" do
      it "returns the list of auths" do
        expect(subject.auths).to be
      end
    end

    describe "#enable_auth" do
      it "enables the auth" do
        expect(subject.enable_auth("enable_auth", "github")).to be(true)
        expect(subject.auths[:enable_auth]).to be
      end
    end

    describe "#disable_auth" do
      it "disables the auth" do
        subject.enable_auth("disable_auth", "github")
        expect(subject.disable_auth("disable_auth")).to be(true)
      end
    end

    describe "#put_auth_tune", vault: ">= 0.6.1" do
      it "writes a config" do
        subject.enable_auth("put_auth_tune", "github")
        expect(subject.put_auth_tune("put_auth_tune", "default_lease_ttl" => 123, "max_lease_ttl" => 456)).to be(true)
        cfg = subject.auth_tune("put_auth_tune")
        expect(cfg.default_lease_ttl).to eq(123)
        expect(cfg.max_lease_ttl).to eq(456)
      end
    end

    describe "#auth_tune", vault: ">= 0.6.1" do
      it "reads a config" do
        subject.enable_auth("auth_tune", "github")
        cfg = subject.auth_tune("auth_tune")
        expect(cfg.default_lease_ttl).to be
        expect(cfg.max_lease_ttl).to be
      end
    end
  end
end
