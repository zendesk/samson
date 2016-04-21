require_relative '../test_helper'

SingleCov.covered!

describe SecretStorage do
  let(:secret) { create_secret 'foo/hello' }

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
      SecretStorage.write('global/foo', value: '111', user_id: users(:admin).id).must_equal true
      secret = SecretStorage::DbBackend::Secret.find('global/foo')
      secret.value.must_equal '111'
      secret.creator_id.must_equal users(:admin).id
      secret.updater_id.must_equal users(:admin).id
    end

    it "refuses to write empty keys" do
      SecretStorage.write('', value: '111', user_id: 11).must_equal false
    end

    it "refuses to write keys with spaces" do
      SecretStorage.write('global/foo ', value: '111', user_id: 11).must_equal false
    end

    it "refuses to write empty values" do
      SecretStorage.write('global/foo', value: '   ', user_id: 11).must_equal false
    end

    it "refuses to write keys we will not be able to replace in commands" do
      SecretStorage.write('a"b', value: '111', user_id: 11).must_equal false
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
      SecretStorage.keys.must_equal ['foo/hello']
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
    describe ".read" do
      before do
        data = {foo: 'bar', data: { secret_data:"bar"}}.to_json
        stub_request(:get, "https://127.0.0.1:8200/v1/secret%2Ffoo%252Fisbar").
          to_return(status: 200, body: data, headers: {'Content-Type': 'application/json'})
      end

      it "gets a value based on a key with /s" do
        SecretStorage::HashicorpVault.read('foo/isbar').must_equal('bar')
      end
    end

    describe ".delete" do
      before do
        stub_request(:delete, "https://127.0.0.1:8200/v1/secret%2Ffoo%2Fisbar").
          to_return(status: 200, body: '', headers: {'Content-Type': 'application/json'})
      end

      it "deletes a key based on a key with /s" do
        assert SecretStorage::HashicorpVault.delete('foo/isbar')
      end
    end

    describe ".delete" do
      before do
        stub_request(:put, "https://127.0.0.1:8200/v1/secret%2Ffoo%252Fisbar").
          to_return(status: 200, body: "", headers: {'Content-Type': 'application/json'})
      end

      it "deletes a key based on a key with /s" do
        assert SecretStorage::HashicorpVault.delete('foo/isbar', 'somevalue')
      end
    end
  end
end
