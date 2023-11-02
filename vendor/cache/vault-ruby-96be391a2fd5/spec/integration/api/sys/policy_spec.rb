require "spec_helper"

module Vault
  describe Sys do
    subject { vault_test_client.sys }

    describe "#policies" do
      it "returns the list of policy names" do
        expect(subject.policies).to be
        expect(subject.policies).to include("root")
      end
    end

    describe "#policy" do
      it "gets the policy by name" do
        policy = %|path "sys" { policy = "deny" }|
        subject.put_policy("test_policy", policy)
        result = subject.policy("test_policy")
        expect(result).to be_a(Policy)
        expect(result.rules).to eq(policy)
      end

      it "returns nil if the policy does not exist" do
        expect(subject.policy("not-a-real-policy")).to be(nil)
      end
    end

    describe "#put_policy" do
      it "creates the policy" do
        policy = %|path "sys" { policy = "deny" }|
        expect(subject.put_policy("test_delete", policy)).to be(true)
        expect(subject.policies).to include("test_delete")

        result = subject.policy("test_delete")
        expect(result).to be_a(Policy)
        expect(result.rules).to eq(policy)
      end
    end

    describe "#delete_policy" do
      it "deletes the policy" do
        subject.put_policy("test_delete", %|path "sys" { policy = "deny" }|)
        expect(subject.delete_policy("test_delete")).to be(true)
        expect(subject.policies).to_not include("test_delete")
      end

      it "does not return an error if the policy does not exist" do
        expect {
          subject.delete_policy("foo")
          subject.delete_policy("foo")
          subject.delete_policy("foo")
        }.to_not raise_error
      end
    end
  end
end
