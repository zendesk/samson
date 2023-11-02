require "spec_helper"

require "fileutils"

module Vault
  describe Sys do
    subject { vault_test_client.sys }

    describe "#audits" do
      it "returns the list of audits" do
        expect(subject.audits).to be
      end
    end

    describe "#enable_audit" do
      it "enables the audit" do
        path = tmp.join("enable_audit.log")
        FileUtils.touch(path)

        subject.enable_audit("test_enable", "file", "", path: path)
        expect(subject.audits[:test_enable]).to be
      end
    end

    describe "#disable_audit" do
      it "disables the audit" do
        path = tmp.join("disable_audit.log")
        FileUtils.touch(path)

        subject.enable_audit("test_disable", "file", "", path: path)
        expect(subject.disable_audit("test_disable")).to be(true)
        expect(subject.audits[:test_disable]).to be(nil)
      end
    end
  end
end
