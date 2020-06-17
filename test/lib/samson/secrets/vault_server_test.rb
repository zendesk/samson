# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::VaultServer do
  let(:server) { Samson::Secrets::VaultServer.new(name: 'abc', address: 'http://vault-land.com', token: "TOKEN") }

  describe "validations" do
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
      assert_request(:get, "http://vault-land.com/v1/secret/apps/?list=true", to_timeout: []) do
        refute_valid server
      end
    end

    it "is invalid when vault connection fails" do
      assert_request(
        :get, "http://vault-land.com/v1/secret/apps/?list=true",
        to_raise: Vault::HTTPError.new("address", stub(code: '200'))
      ) { refute_valid server }
    end

    it "removes valut servers from associated deploy group" do
      deploy_group = deploy_groups(:pod100)
      server.deploy_groups = [deploy_group]
      server.save!
      deploy_group.vault_server.must_equal server
      server.destroy!
      refute deploy_group.reload.vault_server_id
    end
  end

  describe "#sync!" do
    let(:from) { create_vault_server(name: 'pod0') }
    let(:to) { create_vault_server(name: 'pod1') }
    let(:scoped_key) { "staging/foo/pod100/a" }

    before do
      to.deploy_groups = [deploy_groups(:pod100)]
      to.client # cache the client
      to.stubs(:create_client).returns(to.client) # parallel loop creates new independent clients

      from.client # cache the client
      from.stubs(:create_client).returns(from.client) # parallel loop creates new independent clients
    end

    it "copies global keys" do
      key = "global/global/global/a"
      from.client.kv.expects(:list_recursive).returns([key])
      from.client.kv.expects(:read).with(key).returns(stub(data: {foo: :bar}))
      to.client.kv.expects(:write).with(key, foo: :bar)
      to.sync!(from)
    end

    it "copies using respective prefixes" do
      to.update_column(:versioned_kv, true)
      key = "global/global/global/a"

      from.client.kv.expects(:list_recursive).returns([key])
      from.client.kv.expects(:read).with(key).returns(stub(data: {foo: :bar}))
      to.client.kv.expects(:write).with(key, foo: :bar)
      to.sync!(from)
    end

    it "copies keys that this server has access to" do
      key = scoped_key
      from.client.kv.expects(:list_recursive).returns([key])
      from.client.kv.expects(:read).with(key).returns(stub(data: {foo: :bar}))
      to.client.kv.expects(:write).with(key, foo: :bar)
      to.sync!(from)
    end

    it "does not copy keys that should not be kept in this vault by environment" do
      deploy_groups(:pod100).environment.update_column(:permalink, 'nope')
      from.client.kv.expects(:list_recursive).returns([scoped_key])
      from.client.kv.expects(:read).never
      to.client.kv.expects(:write).never
      to.sync!(from)
    end

    it "does not copy keys that should not be kept in this vault by deploy group" do
      deploy_groups(:pod100).update_column(:permalink, 'nope')
      from.client.kv.expects(:list_recursive).returns([scoped_key])
      from.client.kv.expects(:read).never
      to.client.kv.expects(:write).never
      to.sync!(from)
    end
  end

  describe "#refresh_vault_clients" do
    let(:manager) { Samson::Secrets::VaultClientManager.instance }

    around do |test|
      manager.expire_clients
      test.call
      manager.expire_clients
    end

    it "adds new clients" do
      manager.send(:clients).size.must_equal 0
      create_vault_server(name: 'pod0')
      manager.send(:clients).size.must_equal 1
    end

    it "updates client attributes" do
      server = create_vault_server(name: 'pod0')
      manager.send(:clients).size.must_equal 1
      server.update_attribute(:address, 'http://new.com')
      manager.send(:clients).values.first.address.must_equal 'http://new.com'
    end

    it "removes clients" do
      manager.send(:clients).size.must_equal 0
      server = create_vault_server(name: 'pod0')
      manager.send(:clients).size.must_equal 1
      server.destroy!
      manager.send(:clients).size.must_equal 0
    end
  end

  describe "#expire_secrets_cache" do
    let!(:server) { create_vault_server(name: 'pod0') }

    before { server.stubs(:validate_connection) }

    it "expires the secrets cache so keys from the new server get added/removed" do
      Samson::Secrets::Manager.expects(:expire_lookup_cache)
      server.update!(address: "http://foo")
    end

    it "does not expire when unimportant attributes changes" do
      Samson::Secrets::Manager.expects(:expire_lookup_cache).never
      server.update!(name: "Foo")
    end
  end
end
