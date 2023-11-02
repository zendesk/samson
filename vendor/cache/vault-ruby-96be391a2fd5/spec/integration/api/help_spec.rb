require "spec_helper"

module Vault
  describe Help do
    subject { vault_test_client }

    describe "#help" do
      it "returns help for the path" do
        result = subject.help("sys")
        expect(result).to be
        expect(result.help).to include("system backend")
      end

      it "raises an error if no help exists" do
        expect { subject.help("/nope/noway") }.to raise_error(HTTPError)
      end
    end
  end
end
