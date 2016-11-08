# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::VaultServer do
  describe "validations" do
    let(:server) { Samson::Secrets::VaultServer.new(name: 'abc', address: 'http://vault-land.com', token: "TOKEN") }

    before do
      stub_request(:get, "http://vault-land.com/v1/secret/apps/?list=true").
        to_return(headers: {content_type: 'application/json'}, body: {data: {keys: ['abc']}}.to_json)
    end

    it "is valid" do
      assert_valid server
    end

    it "is invalid with only hostname" do
      server.address = server.address.sub('http://', '')
      refute_valid server
    end

    it "is valid with a valid cert" do
      server.ca_cert = File.read("#{fixture_path}/self-signed-test-cert.pem")
      assert_valid server
    end

    it "is invalid with an invalid cert" do
      server.ca_cert = "nope"
      refute_valid server
      server.errors.full_messages.must_equal ["Ca cert is invalid: not enough data"]
    end

    it "is invalid with duplicate name" do
      server.save!
      refute_valid server.dup
    end

    it "is invalid when it cannot connect to vault" do
      stub_request(:get, "http://vault-land.com/v1/secret/apps/?list=true").to_timeout
      refute_valid server
    end

    it "is invalid when vault connection fails" do
      stub_request(:get, "http://vault-land.com/v1/secret/apps/?list=true").
        to_raise(Vault::HTTPError.new("address", stub(code: '200')))
      refute_valid server
    end
  end
end
