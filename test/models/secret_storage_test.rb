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
    let(:client) { SecretStorage::HashicorpVault.send(:vault_client).logical }

    before { client.clear }
    after { client.verify! }

    describe ".read" do
      it "gets a value based on a key with /secret" do
        client.expect('secret/production/foo/pod2/bar', vault: "bar")
        SecretStorage::HashicorpVault.read('production/foo/pod2/bar').must_equal(
          lease_id: nil,
          lease_duration: nil,
          renewable: nil,
          auth: nil,
          value: "bar"
        )
      end

      it "fails to read a key" do
        client.expect('secret/production/foo/pod2/bar', vault: nil)
        assert_raises ActiveRecord::RecordNotFound do
          SecretStorage::HashicorpVault.read('production/foo/pod2/bar')
        end
      end
    end

    describe ".delete" do
      it "deletes key with /secret" do
        assert SecretStorage::HashicorpVault.delete('production/foo/group/isbar')
        client.set.must_equal('secret/production/foo/group/isbar' => nil)
      end
    end

    describe ".write" do
      it "writes a key with /secret" do
        assert SecretStorage::HashicorpVault.write('production/foo/group/isbar/foo', value: 'whatever')
        client.set.must_equal("secret/production/foo/group/isbar%2Ffoo" => {vault: 'whatever'})
      end
    end

    describe ".keys" do
      it "lists all keys with recursion" do
        first_keys = ["production/project/group/this/", "production/project/group/that/"]
        client.expect('list-secret/', first_keys)
        client.expect('list-secret/production/project/group/this/', ["key"])
        client.expect('list-secret/production/project/group/that/', ["key"])
        SecretStorage::HashicorpVault.keys.must_equal(
          [
            "production/project/group/this/key",
            "production/project/group/that/key"
          ]
        )
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
