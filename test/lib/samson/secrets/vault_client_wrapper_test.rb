# frozen_string_literal: true

require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::VaultClientWrapper do
  describe '#initialize' do
    it 'sets versioned_kv' do
      client = Samson::Secrets::VaultClientWrapper.new(versioned_kv: true)
      client.instance_variable_get(:@versioned_kv).must_equal true
    end

    it 'calls Vault::Client initialize with other arguments' do
      client_args = {versioned_kv: true, use_ssl: true, timeout: 543, ssl_timeout: 345}

      client = Samson::Secrets::VaultClientWrapper.new(**client_args)

      client.instance_variable_get(:@ssl_verify).must_equal true
      client.instance_variable_get(:@timeout).must_equal 543
      client.instance_variable_get(:@ssl_timeout).must_equal 345
    end
  end

  describe '#initialize' do
    describe 'versioned' do
      let(:client) { Samson::Secrets::VaultClientWrapper.new(versioned_kv: false).kv }

      it 'instantiates an unversioned logical wrapper if server is unversioned' do
        client.must_be_instance_of Samson::Secrets::VaultLogicalWrapper
      end
    end

    describe 'unversioned' do
      let(:client) { Samson::Secrets::VaultClientWrapper.new(versioned_kv: true).kv }

      it 'instantiates a versioned logical wrapper if server is versioned' do
        client.must_be_instance_of Samson::Secrets::VaultKvWrapper
      end
    end
  end
end
