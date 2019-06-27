# frozen_string_literal: true

require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::VaultKVWrapper do
  # TODO: use VaultRequestHelper
  let(:server) { create_vault_server(name: 'pod0', versioned_kv: true) }

  describe '#list' do
    it 'lists keys' do
      stub_request(:get, 'http://vault-land.com/v1/secret/metadata/apps/?list=true').
        to_return(headers: {content_type: 'application/json'}, body: {data: {keys: [+'foo']}}.to_json)

      server.client.kv.list.must_equal ['foo']
    end
  end

  describe '#read' do
    it 'reads secrets' do
      stub_request(:get, 'http://vault-land.com/v1/secret/data/apps/foo/bar').
        to_return(headers: {content_type: 'application/json'}, body: {data: {data: {cool: 'beans'}}}.to_json)

      result = server.client.kv.read('foo/bar')
      result.must_be_instance_of Vault::Secret
      result.data.must_equal cool: 'beans'
    end

    it 'reads secret versions' do
      stub_request(:get, 'http://vault-land.com/v1/secret/data/apps/foo/bar?version=v1').
        to_return(headers: {content_type: 'application/json'}, body: {data: {data: {cool: 'beans'}}}.to_json)

      result = server.client.kv.read('foo/bar', 'v1')
      result.data.must_equal cool: 'beans'
    end
  end

  describe '#read_metadata' do
    it 'reads metadata' do
      stub_request(:get, 'http://vault-land.com/v1/secret/metadata/apps/foo/bar').
        to_return(headers: {content_type: 'application/json'}, body: {data: {cool: 'beans'}}.to_json)

      result = server.client.kv.read_metadata('foo/bar')
      result.must_be_instance_of Hash
      result.must_equal cool: 'beans'
    end
  end

  describe '#write' do
    it 'writes secrets' do
      stub_request(:post, 'http://vault-land.com/v1/secret/data/apps/super_secret').
        with(body: {data: {cool: 'beans'}}).
        to_return(
          status: 200,
          headers: {content_type: 'application/json'},
          body: {data: {version: '1', destroyed: 'false'}}.to_json
        )

      result = server.client.kv.write('super_secret', cool: 'beans')
      result.data.must_equal version: '1', destroyed: 'false'
    end
  end

  describe '#delete' do
    it 'deletes secrets' do
      stub_request(:delete, 'http://vault-land.com/v1/secret/data/apps/foo/my_secret').to_return(status: 204)

      server.client.kv.delete('foo/my_secret')
    end
  end

  describe '#list_recursive' do
    it 'iterates through all keys' do
      stub_request(:get, 'http://vault-land.com/v1/secret/metadata/apps/?list=true').
        to_return(headers: {content_type: 'application/json'}, body: {data: {keys: [+'abc/', +'def']}}.to_json)
      stub_request(:get, 'http://vault-land.com/v1/secret/metadata/apps/abc/?list=true').
        to_return(headers: {content_type: 'application/json'}, body: {data: {keys: [+'ghi']}}.to_json)

      Samson::Secrets::VaultServer.any_instance.unstub(:validate_connection)
      server.client.kv.list_recursive.must_equal ['abc/ghi', 'def']
    end
  end
end
