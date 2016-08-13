# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SecretStorage do
  let(:secret) { create_secret 'production/foo/pod2/hello' }

  describe ".allowed_project_prefixes" do
    it "is all for admin" do
      SecretStorage.allowed_project_prefixes(users(:admin)).must_equal ['global'] + Project.pluck(:permalink).sort
    end

    it "is allowed for project admin" do
      SecretStorage.allowed_project_prefixes(users(:project_admin)).must_equal ['foo']
    end
  end

  describe ".write" do
    it "writes" do
      secret_key = 'production/foo/pod2/hello'
      SecretStorage.write(secret_key, value: '111', user_id: users(:admin).id).must_equal true
      secret = SecretStorage::DbBackend::Secret.find(secret_key)
      secret.value.must_equal '111'
      secret.creator_id.must_equal users(:admin).id
      secret.updater_id.must_equal users(:admin).id
    end

    it "refuses to write empty keys" do
      SecretStorage.write('', value: '111', user_id: 11).must_equal false
    end

    it "refuses to write keys with spaces" do
      SecretStorage.write('  production/foo/pod2/hello', value: '111', user_id: 11).must_equal false
    end

    it "refuses to write empty values" do
      SecretStorage.write('production/foo/pod2/hello', value: '   ', user_id: 11).must_equal false
    end

    it "refuses to write keys we will not be able to replace in commands" do
      SecretStorage.write('a"b', value: '111', user_id: 11).must_equal false
    end
  end

  describe ".parse_secret_key" do
    it "parses parts" do
      SecretStorage.parse_secret_key('marry/had/a/little/lamb').must_equal(
        environment_permalink: "marry",
        project_permalink: "had",
        deploy_group_permalink: "a",
        key: "little/lamb"
      )
    end

    it "ignores missing parts" do
      SecretStorage.parse_secret_key('').must_equal(
        environment_permalink: nil,
        project_permalink: nil,
        deploy_group_permalink: nil,
        key: nil
      )
    end
  end

  describe ".generate_secret_key" do
    it "generates a private key" do
      SecretStorage.generate_secret_key(
        environment_permalink: 'production',
        project_permalink: 'foo',
        deploy_group_permalink: 'bar',
        key: 'snafu'
      ).must_equal("production/foo/bar/snafu")
    end

    it "fails raises when missing keys" do
      assert_raises KeyError do
        SecretStorage.generate_secret_key({})
      end
    end
  end

  describe ".read" do
    it "reads" do
      data = SecretStorage.read(secret.id, include_secret: true)
      data.fetch(:value).must_equal 'MY-SECRET'
    end

    it "does not read secrets by default" do
      data = SecretStorage.read(secret.id)
      refute data.key?(:value)
    end

    it "raises on unknown" do
      assert_raises ActiveRecord::RecordNotFound do
        SecretStorage.read('dfsfsfdsdf')
      end
    end
  end

  describe ".read_multi" do
    it "reads" do
      data = SecretStorage.read_multi([secret.id], include_secret: true)
      data.keys.must_equal [secret.id]
      data[secret.id].fetch(:value).must_equal 'MY-SECRET'
    end

    it "does not read secrets by default" do
      data = SecretStorage.read_multi([secret.id])
      refute data[secret.id].key?(:value)
    end

    it "returns empty for unknown" do
      SecretStorage.read_multi([secret.id, 'dfsfsfdsdf']).keys.must_equal [secret.id]
      SecretStorage.read_multi(['dfsfsfdsdf']).keys.must_equal []
    end
  end

  describe ".delete" do
    it "deletes" do
      SecretStorage.delete(secret.id)
      refute SecretStorage::DbBackend::Secret.exists?(secret.id)
    end
  end

  describe ".keys" do
    it "lists keys" do
      secret # trigger creation
      SecretStorage.keys.must_equal ['production/foo/pod2/hello']
    end
  end

  describe SecretStorage::DbBackend::Secret do
    # A hack to make attr_encrypted always behave the same even when loaded without a database being present.
    # On load it checks if the column exists and then defined attr_accessors if they do not.
    # Reproduce with: `CI=1 RAILS_ENV=test rake db:drop db:create default`
    # https://github.com/attr-encrypted/attr_encrypted/issues/226
    if ENV['CI'] && SecretStorage::DbBackend::Secret.instance_methods.include?(:encrypted_value_iv)
      [:encrypted_value_iv, :encrypted_value_iv=, :encrypted_value, :encrypted_value=].each do |m|
        SecretStorage::DbBackend::Secret.send(:undef_method, m)
      end
    end

    describe "#value " do
      it "is encrypted" do
        secret.value.must_equal "MY-SECRET"
        secret.encrypted_value.size.must_be :>, 10 # cannot assert equality since it is always different
      end

      it "can decrypt existing" do
        SecretStorage::DbBackend::Secret.find(secret.id).value.must_equal "MY-SECRET"
      end
    end

    describe "#store_encryption_key_sha" do
      it "stores the encryption key sha so we can rotate it in the future" do
        secret.encryption_key_sha.must_equal "c975b468c4677aa69a20769bf9553ea1937b84684c2876130f9c528731963f4d"
      end
    end

    describe "validations" do
      it "is valid" do
        assert_valid secret
      end

      it "is invalid without secret" do
        secret.value = nil
        refute_valid secret
      end

      it "is invalid without id" do
        secret.id = nil
        refute_valid secret
      end

      it "is invalid without key" do
        secret.id = "a/b/c/"
        refute_valid secret
      end

      it "is valid with keys with slashes" do
        secret.id = "a/b/c/d/e/f/g"
        assert_valid secret
      end
    end
  end

  describe SecretStorage::HashicorpVault do
    let(:client) { SecretStorage::HashicorpVault.send(:vault_client) }
    let(:secret_namespace) { "secret/apps/" }

    around { |test| Dir.mktmpdir { |dir| Dir.chdir(dir) { test.call } } }
    before { client.clear }
    after { client.verify! }

    describe "missing config file" do
      before { client.remove_config }
      after { client.create_config }
      it "fails without a config file" do
        e = assert_raises RuntimeError do
          client.ensure_config_exists
        end
        e.message.must_include "config file missing"
      end
    end

    describe ".read" do
      it "gets a value based on a key with /secret" do
        client.expect(secret_namespace + 'production/foo/pod2/bar', vault: "bar")
        SecretStorage::HashicorpVault.read('production/foo/pod2/bar').must_equal(
          lease_id: nil,
          lease_duration: nil,
          renewable: nil,
          auth: nil,
          value: "bar"
        )
      end

      it "fails to read a key" do
        client.expect(secret_namespace + 'production/foo/pod2/bar', vault: nil)
        SecretStorage::HashicorpVault.read('production/foo/pod2/bar').must_equal nil
      end
    end

    describe ".read_multi" do
      it "gets a value based on a key with /secret" do
        client.expect(secret_namespace + 'production/foo/pod2/bar', vault: "bar")
        SecretStorage::HashicorpVault.read_multi(['production/foo/pod2/bar']).must_equal('production/foo/pod2/bar' => {
          lease_id: nil,
          lease_duration: nil,
          renewable: nil,
          auth: nil,
          value: "bar"
        })
      end

      it "fails to read a key" do
        client.expect(secret_namespace + 'production/foo/pod2/bar', vault: nil)
        SecretStorage::HashicorpVault.read_multi(['production/foo/pod2/bar']).must_equal({})
      end
    end

    describe ".delete" do
      it "deletes key with /secret" do
        assert SecretStorage::HashicorpVault.delete('production/foo/group/isbar')
        client.set.must_equal(secret_namespace + 'production/foo/group/isbar' => nil)
      end
    end

    describe ".write" do
      it "writes a key with /secret" do
        assert SecretStorage::HashicorpVault.write('production/foo/group/isbar/foo', value: 'whatever')
        client.set.must_equal(secret_namespace + "production/foo/group/isbar%2Ffoo" => {vault: 'whatever'})
      end
    end

    describe ".keys" do
      it "lists all keys with recursion" do
        first_keys = ["production/project/group/this/", "production/project/group/that/"]
        client.expect('list-secret/apps/', first_keys)
        client.expect('list-secret/apps/production/project/group/this/', ["key"])
        client.expect('list-secret/apps/production/project/group/that/', ["key"])
        SecretStorage::HashicorpVault.keys.must_equal(
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
          SecretStorage::HashicorpVault.read('production/foo/whateverman/bar')
        end
        e.message.must_include("no vault_instance configured for deploy group whateverman")
      end

      it "works with a global deploy group" do
        client.expect(secret_namespace + 'production/foo/global/bar', vault: "bar")
        assert SecretStorage::HashicorpVault.read('production/foo/global/bar')
      end
    end

    describe ".vault_client" do
      it 'creates a valid client' do
        assert_instance_of(::VaultClient, SecretStorage::HashicorpVault.send(:vault_client))
      end
    end

    describe ".convert_path" do
      it "fails with invalid direction" do
        assert_raises ArgumentError do
          SecretStorage::HashicorpVault.send(:convert_path, 'x', :ooops)
        end
      end
    end
  end
end
