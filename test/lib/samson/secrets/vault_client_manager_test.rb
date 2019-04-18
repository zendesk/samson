# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::VaultClientManager do
  include VaultRequestHelper

  # have 2 servers around so we can test multi-server logic
  before do
    server = create_vault_server(name: 'pod100', token: 'POD100-TOKEN')
    deploy_groups(:pod100).update_column(:vault_server_id, server.id)
    manager.expire_clients
  end

  let(:manager) { Samson::Secrets::VaultClientManager.new }

  describe ".instance" do
    it "is cached" do
      Samson::Secrets::VaultClientManager.instance.object_id.must_equal(
        Samson::Secrets::VaultClientManager.instance.object_id
      )
    end
  end

  describe "#initialize" do
    let(:clients) { manager.send(:clients) }

    it "creates clients without certs" do
      refute clients.values.first.options.fetch(:ssl_cert_store)
    end

    it "adds certs when server has a ca_cert" do
      Samson::Secrets::VaultServer.update_all(ca_cert: File.read("#{fixture_path}/self-signed-test-cert.pem"))
      assert clients.values.first.options.fetch(:ssl_cert_store)
    end
  end

  describe "#read" do
    it "only reads from first server" do
      assert_vault_request :get, 'global/global/global/foo', body: {data: {foo: :bar}}.to_json do
        manager.read('global/global/global/foo').class.must_equal(Vault::Secret)
      end
    end

    it "reads from the preferred server" do
      create_vault_server(address: 'http://pick-me.com', name: 'pod101', token: 'POD100-TOKEN', preferred_reader: true)
      create_vault_server(address: 'http://not-me.com', name: 'pod102', token: 'POD100-TOKEN')
      assert_vault_request(
        :get, 'global/global/global/foo', address: 'http://pick-me.com', body: {data: {foo: :bar}}.to_json
      ) { manager.read('global/global/global/foo') }
    end
  end

  describe "#read_metadata" do
    before { Samson::Secrets::VaultServer.update_all(versioned_kv: true) }

    it "only reads from first server" do
      body = {data: {foo: :bar}}.to_json
      assert_vault_request :get, 'global/global/global/foo', versioned_kv: "metadata", body: body do
        manager.read_metadata('global/global/global/foo').must_equal(foo: "bar")
      end
    end
  end

  describe "#write" do
    it "writes to all servers" do
      assert_vault_request :put, 'global/global/global/foo', times: 2 do
        manager.write('global/global/global/foo', foo: :bar)
      end
    end
  end

  describe "#delete" do
    it "deletes from matching servers" do
      assert_vault_request :delete, 'staging/global/pod100/foo', times: 1 do
        manager.delete('staging/global/pod100/foo')
      end
    end

    it "can delete from all servers to remove broken ids" do
      assert_vault_request :delete, 'staging/global/pod100/foo', times: 2 do
        manager.delete('staging/global/pod100/foo', all: true)
      end
    end
  end

  describe "#list_recursive" do
    it "combines lists from all servers" do
      assert_vault_request :get, '?list=true', body: {data: {keys: ['abc']}}.to_json, times: 2 do
        manager.list_recursive.must_equal ['abc']
      end
    end

    it "does not fail when a single server fails" do
      Samson::ErrorNotifier.expects(:notify).times(2)
      assert_vault_request :get, '?list=true', status: 500, times: 2 do
        manager.list_recursive.must_equal []
      end
    end
  end

  describe "#renew_token" do
    it "renews the token" do
      assert_request(
        :put,
        "http://vault-land.com/v1/auth/token/renew-self",
        to_return: {body: "{}", headers: {content_type: 'application/json'}},
        times: 2
      ) { manager.renew_token }
    end

    it "does not prevent renewing all tokens when a single renew fails" do
      Samson::ErrorNotifier.expects(:notify).times(2)
      assert_request(
        :put,
        "http://vault-land.com/v1/auth/token/renew-self",
        to_timeout: [],
        times: 8 # 2 servers with 1 initial try and 3 re-tries
      ) { manager.renew_token }
    end
  end

  describe "#clients" do
    it "scopes to matching deploy group" do
      Samson::Secrets::VaultServer.last.update_column(:address, 'do-not-use')
      assert_vault_request :put, 'global/global/pod2/foo' do
        manager.write('global/global/pod2/foo', foo: :bar)
      end
    end

    describe "environment matching" do
      before do
        # make sure we never write to staging pod100
        Samson::Secrets::VaultServer.last.update_column(:address, 'do-not-use')
      end

      it "scopes to matching environment" do
        deploy_groups(:pod1).update_attribute(:vault_server_id, deploy_groups(:pod2).vault_server_id)
        assert_vault_request :put, 'production/global/global/foo' do
          manager.write('production/global/global/foo', foo: :bar)
        end
      end

      it "ignores when not all deploy groups in that environment have a vault server" do
        assert_vault_request :put, 'production/global/global/foo' do
          manager.write('production/global/global/foo', foo: :bar)
        end
      end

      it "fails when no servers were found" do
        deploy_groups(:pod1).delete
        deploy_groups(:pod2).delete
        e = assert_raises(RuntimeError) { manager.write('production/global/global/foo', foo: :bar) }
        e.message.must_equal "no vault servers found for production/global/global/foo"
      end

      it "fails with unknown environment" do
        e = assert_raises(RuntimeError) { manager.write('unfound/global/global/foo', foo: :bar) }
        e.message.must_equal "no environment with permalink unfound found"
      end
    end

    it "fails descriptively when not deploy group was found" do
      e = assert_raises(RuntimeError) do
        manager.write('global/global/podoops/foo', foo: :bar)
      end
      e.message.must_equal "no deploy group with permalink podoops found"
    end
  end

  describe "#client" do
    it "finds correct client" do
      manager.send(:client, deploy_groups(:pod2).permalink).options.fetch(:token).must_equal 'TOKEN'
    end

    it "fails descriptively when deploy group has no vault server associated" do
      deploy_groups(:pod2).update_column(:vault_server_id, nil)
      manager.expire_clients
      e = assert_raises(Samson::Secrets::VaultClientManager::VaultServerNotConfigured) do
        manager.send(:client, deploy_groups(:pod2).permalink)
      end
      e.message.must_equal "deploy group pod2 has no vault server configured"
    end

    it "fails descriptively when vault client cannot be found" do
      manager # trigger caching
      deploy_groups(:pod2).update_column(:vault_server_id, 123)
      e = assert_raises(RuntimeError) { manager.send(:client, deploy_groups(:pod2).permalink) }
      e.message.must_equal "no vault server found with id 123"
    end

    it "loads everything without doing N+1" do
      assert_sql_queries(4) do
        3.times { manager.send(:responsible_clients, 'global/global/global/bar') }
        3.times { manager.send(:responsible_clients, 'staging/global/pod100/foo') }
      end
    end
  end
end
