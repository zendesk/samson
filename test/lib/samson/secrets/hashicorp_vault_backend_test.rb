# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::HashicorpVaultBackend do
  let(:client) { Samson::Secrets::HashicorpVaultBackend.send(:vault_client) }
  let(:secret_namespace) { "secret/apps/" }

  around { |test| Dir.mktmpdir { |dir| Dir.chdir(dir) { test.call } } }
  before { client.clear }
  after { client.verify! }

  describe ".read" do
    it "gets a value based on a key with /secret" do
      client.expect(secret_namespace + 'production/foo/pod2/bar', vault: "bar")
      Samson::Secrets::HashicorpVaultBackend.read('production/foo/pod2/bar').must_equal(
        lease_id: nil,
        lease_duration: nil,
        renewable: nil,
        auth: nil,
        value: "bar"
      )
    end

    it "fails to read a key" do
      client.expect(secret_namespace + 'production/foo/pod2/bar', vault: nil)
      Samson::Secrets::HashicorpVaultBackend.read('production/foo/pod2/bar').must_equal nil
    end
  end

  describe ".read_multi" do
    it "gets a value based on a key with /secret" do
      client.expect(secret_namespace + 'production/foo/pod2/bar', vault: "bar")
      Samson::Secrets::HashicorpVaultBackend.read_multi(['production/foo/pod2/bar']).must_equal(
        'production/foo/pod2/bar' => {
          lease_id: nil,
          lease_duration: nil,
          renewable: nil,
          auth: nil,
          value: "bar"
        }
      )
    end

    it "fails to read a key" do
      client.expect(secret_namespace + 'production/foo/pod2/bar', vault: nil)
      Samson::Secrets::HashicorpVaultBackend.read_multi(['production/foo/pod2/bar']).must_equal({})
    end
  end

  describe ".delete" do
    it "deletes key with /secret" do
      assert Samson::Secrets::HashicorpVaultBackend.delete('production/foo/group/isbar')
      client.set.must_equal(secret_namespace + 'production/foo/group/isbar' => nil)
    end
  end

  describe ".write" do
    it "writes a key with /secret" do
      assert Samson::Secrets::HashicorpVaultBackend.write(
        'production/foo/group/isbar/foo', value: 'whatever', visible: false, user_id: 1, comment: 'secret!'
      )
      client.set.must_equal(
        secret_namespace + "production/foo/group/isbar%2Ffoo" =>
          {vault: 'whatever', visible: false, comment: 'secret!', creator_id: 1}
      )
    end
  end

  describe ".keys" do
    it "lists all keys with recursion" do
      first_keys = ["production/project/group/this/", "production/project/group/that/"]
      client.expect('list-secret/apps/', first_keys)
      client.expect('list-secret/apps/production/project/group/this/', ["key"])
      client.expect('list-secret/apps/production/project/group/that/', ["key"])
      Samson::Secrets::HashicorpVaultBackend.keys.must_equal(
        [
          "production/project/group/this/key",
          "production/project/group/that/key"
        ]
      )
    end
  end

  describe "vault instances" do
    it "fails to find a vault instance for the deploy group" do
      e = assert_raises KeyError do
        Samson::Secrets::HashicorpVaultBackend.read('production/foo/whateverman/bar')
      end
      e.message.must_include("no vault_instance configured for deploy group whateverman")
    end

    it "works with a global deploy group" do
      client.expect(secret_namespace + 'production/foo/global/bar', vault: "bar")
      assert Samson::Secrets::HashicorpVaultBackend.read('production/foo/global/bar')
    end
  end

  describe ".vault_client" do
    it 'creates a valid client' do
      assert_instance_of(::VaultClient, Samson::Secrets::HashicorpVaultBackend.send(:vault_client))
    end
  end

  describe ".convert_path" do
    it "fails with invalid direction" do
      assert_raises ArgumentError do
        Samson::Secrets::HashicorpVaultBackend.send(:convert_path, 'x', :ooops)
      end
    end
  end
end
