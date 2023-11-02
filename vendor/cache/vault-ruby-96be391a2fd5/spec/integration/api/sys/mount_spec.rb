require "spec_helper"

module Vault
  describe Sys do
    subject { vault_test_client.sys }

    describe "#mounts" do
      it "lists the mounts" do
        expect(subject.mounts).to be
        sys = subject.mounts[:sys]
        expect(sys).to be_a(Mount)
        expect(sys.type).to eq("system")
        expect(sys.description).to include("system endpoints")
      end
    end

    describe "#mount" do
      it "gets the mount by name" do
        expect(subject.mount("test_mount", "aws")).to be(true)
        result = subject.mounts[:test_mount]
        expect(result).to be_a(Mount)
        expect(result.type).to eq("aws")
        expect(result.description).to eq("")
      end
    end

    describe "#mount_tune" do
      it "tunes the mount" do
        expect(subject.mount("test_mount_tune", "aws")).to be(true)
        expect(subject.mount_tune("test_mount_tune", max_lease_ttl: '1234h'))
        result = subject.mounts[:test_mount_tune]
        expect(result).to be_a(Mount)
        expect(result.config[:max_lease_ttl]).to eq(1234*60*60)
      end
    end

    describe "#unmount" do
      it "unmounts by name" do
        subject.mount("test_unmount", "aws")
        expect(subject.unmount("test_unmount")).to be(true)
      end
    end

    describe "#remount" do
      it "remounts at the new path" do
        subject.mount("test_remount", "aws")
        subject.remount("test_remount", "new_test_remount")
        expect(subject.mounts[:test_remount]).to be(nil)
        expect(subject.mounts[:new_test_remount]).to be
      end
    end
  end
end
