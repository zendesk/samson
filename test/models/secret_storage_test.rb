require_relative '../test_helper'

SingleCov.covered! uncovered: 4

describe SecretStorage do
  let(:secret) { create_secret 'environment/foo/deploy_group/hello' }
  before do
    create_secret_test_group
  end

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
      SecretStorage.write('environment/foo/deploy_group/hello', value: '111', user_id: users(:admin).id).must_equal true
      secret = SecretStorage::DbBackend::Secret.find('environment/foo/deploy_group/hello')
      secret.value.must_equal '111'
      secret.creator_id.must_equal users(:admin).id
      secret.updater_id.must_equal users(:admin).id
    end

    it "refuses to write empty keys" do
      SecretStorage.write('', value: '111', user_id: 11).must_equal false
    end

    it "refuses to write keys with spaces" do
      SecretStorage.write('  environment/foo/deploy_group/hello', value: '111', user_id: 11).must_equal false
    end

    it "refuses to write empty values" do
      SecretStorage.write('environment/foo/deploy_group/hello', value: '   ', user_id: 11).must_equal false
    end

    it "refuses to write keys we will not be able to replace in commands" do
      SecretStorage.write('a"b', value: '111', user_id: 11).must_equal false
    end
  end

  describe ".parses keys" do
    let(:secret_key) { 'marry/had/a/little' }
    it "returs the environment" do
      SecretStorage.parse_secret_key(secret_key, :environment).must_equal('marry')
    end

    it "returs the project" do
      SecretStorage.parse_secret_key(secret_key, :project).must_equal('had')
    end

    it "returs the deploy_group" do
      SecretStorage.parse_secret_key(secret_key, :deploy_group).must_equal('a')
    end

    it "returs the key" do
      SecretStorage.parse_secret_key(secret_key, :key).must_equal('little')
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
      SecretStorage.keys.must_equal ['environment/foo/deploy_group/hello']
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
    # note, we need to call the storage engine here directly
    # as the model has already loaded it's config
    # from ENV
    before do
      ENV["SECRET_STORAGE_BACKEND"] = "SecretStorage::HashicorpVault"
    end
    describe ".read" do
      before do
        data = {data: { vault:"bar"}}.to_json
        stub_request(:get, "https://127.0.0.1:8200/v1/secret%2Fproduction%2Ffoo%2Fdeploy_group%2Fisbar").
          to_return(status: 200, body: data, headers: {'Content-Type': 'application/json'})
        fail_data = {data: { vault:nil}}.to_json
        # client gets a 200 and nil body when key is missing
        stub_request(:get, "https://127.0.0.1:8200/v1/secret%2Fnotgoingtobethere").
          to_return(status: 200, body: fail_data, headers: {'Content-Type': 'application/json'})
        # this is the auth request, just needs to return 200 for our purposes
        stub_request(:post, "https://127.0.0.1:8200/v1/auth/cert/login")
      end

      it "gets a value based on a key with /s" do
        SecretStorage::HashicorpVault.read('production/foo/deploy_group/isbar').must_equal({:lease_id=>nil, :lease_duration=>nil, :renewable=>nil, :auth=>nil, :value=>"bar"})
      end

      it "fails to read a key" do
        assert_raises ActiveRecord::RecordNotFound do
          SecretStorage::HashicorpVault.read('notgoingtobethere')
        end
      end

      it "invalid key conversion fails for a read" do
        assert_raises ArgumentError do
          SecretStorage::HashicorpVault.convert_path('foopy%2Fthecat', :notvalid)
        end
      end
    end

    describe ".delete" do
      before do
        stub_request(:delete, "https://127.0.0.1:8200/v1/secret%2Fproduction%2Ffoo%2Fgroup%2Fisbar")
      end

      it "deletes key with /s" do
        assert SecretStorage::HashicorpVault.delete('production/foo/group/isbar')
      end
    end

    describe ".write" do
      before do
        stub_request(:put, "https://127.0.0.1:8200/v1/secret%2Fenv%2F%2Fbar%2Fisbar").
          with(:body => "{\"vault\":\"whatever\"}")
      end

      it "wirtes a key with /s" do
        assert SecretStorage::HashicorpVault.write('production/foo/group/isbar', {environment_permalink: 'env', project_permalinl: 'foo', deploy_group_permalink: 'bar', value: 'whatever'})
      end
    end

    describe ".keys" do
      before do
        data = {"data": { "keys": ["production/project/group/this%2Fkey", "production/project/group/that%2Fkey"] } }.to_json
        stub_request(:get, "https://127.0.0.1:8200/v1/secret%2F?list=true").
          to_return(status: 200, body: data, headers: {'Content-Type': 'application/json'})
      end

      it "lists all keys with recursion" do
        SecretStorage::HashicorpVault.keys().must_equal(["production/project/group/this/key", "production/project/group/that/key"])
      end
    end
  end
end
