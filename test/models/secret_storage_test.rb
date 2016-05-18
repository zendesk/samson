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

  describe ".parse_secret_key_part" do
    let(:secret_key) { 'marry/had/a/little' }
    it "returs the environment" do
      SecretStorage.parse_secret_key_part(secret_key, :environment).must_equal('marry')
    end

    it "returns the project" do
      SecretStorage.parse_secret_key_part(secret_key, :project).must_equal('had')
    end

    it "returns the deploy_group" do
      SecretStorage.parse_secret_key_part(secret_key, :deploy_group).must_equal('a')
    end

    it "returns the key" do
      SecretStorage.parse_secret_key_part(secret_key, :key).must_equal('little')
    end

    it "fails with invalid key" do
      SecretStorage.parse_secret_key_part('foo/bar/whatever', :key).must_be_nil
    end
  end

  describe ". generate_secret_key" do
    it "generates a private key" do
      SecretStorage.generate_secret_key('production', 'foo', 'bar', 'snafu').must_equal("production/foo/bar/snafu")
    end

    it "fails raises when missing environment" do
      assert_raises ArgumentError do
        SecretStorage.generate_secret_key(nil, 'foo', 'bar', 'snafu')
      end
    end

    it "fails raises when missing project" do
      assert_raises ArgumentError do
        SecretStorage.generate_secret_key('env', nil, 'bar', 'snafu')
      end
    end

    it "fails raises when missing deploy_group" do
      assert_raises ArgumentError do
        SecretStorage.generate_secret_key('env', 'foo', nil, 'snafu')
      end
    end

    it "fails raises when missing key" do
      assert_raises ArgumentError do
        SecretStorage.generate_secret_key('env', 'foo', 'group', nil)
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

    describe "#store_encryption_key_sha"do
      it "stores the encryption key sha so we can rotate it in the future" do
        secret.encryption_key_sha.must_equal "c975b468c4677aa69a20769bf9553ea1937b84684c2876130f9c528731963f4d"
      end
    end
  end

  describe SecretStorage::HashicorpVault do
    let(:response_headers) { {'Content-Type': 'application/json'} }

    describe ".client" do
      it 'creates a valid client' do
        assert_instance_of(VaultClient, SecretStorage::HashicorpVault.vault_client)
      end
    end

    describe ".read" do
      before do
        fail_data = {data: { vault:nil}}.to_json
        # client gets a 200 and nil body when key is missing
        stub_request(:get, "https://127.0.0.1:8200/v1/secret/this/key/isnot/there").
          to_return(status: 200, body: fail_data, headers: {'Content-Type': 'application/json'})
        # this is the auth request, just needs to return 200 for our purposes
        stub_request(:post, "https://127.0.0.1:8200/v1/auth/cert/login")
        # using the stubbed client
        stub_request(:get, "https://127.0.0.1:8200/v1/secret/production/foo/pod2/isbar").
          to_return(status: 200, headers: {'Content-Type': 'application/json'})
        stub_request(:get, "https://127.0.0.1:8200/v1/secret/notgoingtobethere").
          to_return(status: 200, headers: {'Content-Type': 'application/json'})
        not_branch = ['is_now_a_leaf']
        stub_request(:get, "https://127.0.0.1:8200/v1/secret/?list=true").
          to_return(status: 200, body: not_branch, headers: response_headers)
      end

      it "gets a value based on a key with /s" do
        SecretStorage::HashicorpVault.read('production/foo/pod2/isbar').must_equal({
          lease_id: nil,
          lease_duration: nil,
          renewable: nil,
          auth: nil,
          value: "bar"
        })
      end

      it "fails to read a key" do
        assert_raises ActiveRecord::RecordNotFound do
          SecretStorage::HashicorpVault.read('this/key/isnot/there')
        end
      end

      it "invalid key conversion fails for a read" do
        assert_raises ArgumentError do
          SecretStorage::HashicorpVault.convert_path('foopy%2Fthecat', :notvalid)
        end
      end

      it "recusivly translates keys" do
        assert SecretStorage::HashicorpVault.keys
      end
    end

    describe ".delete" do
      before do
        stub_request(:delete, "http://127.0.0.1:8200/v1/secret/production/foo/group/isbar")
      end

      it "deletes key with /s" do
        assert SecretStorage::HashicorpVault.delete('production/foo/group/isbar')
      end
    end

    describe ".write" do
      before do
        stub_request(:put, "https://127.0.0.1:8200/v1/secret/env/foo/bar/isbar%2Ffoo").
          with(:body => "{\"vault\":\"whatever\"}")
      end

      it "wirtes a key with /s" do
        assert SecretStorage::HashicorpVault.write('production/foo/group/isbar/foo', {environment_permalink: 'env', project_permalink: 'foo', deploy_group_permalink: 'bar', key_permalink: 'isbar', value: 'whatever'})
      end
    end

    describe ".keys" do
      before do
        first_keys = ["production/project/group/this/", "production/project/group/that/"]
        stub_request(:get, "https://127.0.0.1:8200/v1/secret/?list=true").
          to_return(status: 200, body: first_keys, headers: response_headers)

        stub_request(:get, "https://127.0.0.1:8200/v1/secret/production/project/group/this/?list=true").
          to_return(status: 200, body: ["key"], headers: response_headers)

        stub_request(:get, "https://127.0.0.1:8200/v1/secret/production/project/group/that/?list=true").
          to_return(status: 200, body: ["key"], headers: response_headers)

        stub_request(:get, "https://127.0.0.1:8200/v1/secret/production/project/group/this/key?list=true").
          to_return(status: 200, body: [], headers: response_headers)

        stub_request(:get, "https://127.0.0.1:8200/v1/secret/production/project/group/that/key?list=true").
          to_return(status: 200, body: [], headers: response_headers)


      end

      it "lists all keys with recursion" do
        SecretStorage::HashicorpVault.keys().must_equal([
          "production/project/group/this/key",
          "production/project/group/that/key"
        ])
      end
    end
  end
end
