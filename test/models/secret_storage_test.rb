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
    let(:attributes) { {value: '111', user_id: users(:admin).id, visible: false, comment: 'comment'} }

    it "writes" do
      id = 'production/foo/pod2/hello'
      SecretStorage.write(id, attributes).must_equal true
      secret = SecretStorage::DbBackend::Secret.find(id)
      secret.value.must_equal '111'
      secret.creator_id.must_equal users(:admin).id
      secret.updater_id.must_equal users(:admin).id
    end

    it "adds id to ids cache" do
      secret # create
      SecretStorage.ids.must_equal([secret.id]) # fill and check cache
      SecretStorage.backend.expects(:ids).never # block call

      id = 'production/foo/pod2/world'
      SecretStorage.write(id, attributes).must_equal true
      SecretStorage.ids.sort.must_equal [secret.id, id]
    end

    it "does not add known id to ids cache" do
      secret # create
      SecretStorage.ids.must_equal([secret.id]) # fill and check cache
      SecretStorage.backend.expects(:ids).never # block call

      SecretStorage.write(secret.id, attributes).must_equal true
      SecretStorage.ids.sort.must_equal [secret.id]
    end

    it "refuses to write empty ids" do
      SecretStorage.write('', attributes).must_equal false
    end

    it "refuses to write ids with spaces" do
      SecretStorage.write('  production/foo/pod2/hello', attributes).must_equal false
    end

    it "refuses to write empty values" do
      SecretStorage.write('production/foo/pod2/hello', attributes.merge(value: '   ')).must_equal false
    end

    it "refuses to write ids we will not be able to replace in commands" do
      SecretStorage.write('a"b', attributes).must_equal false
    end
  end

  describe ".parse_id" do
    it "parses parts" do
      SecretStorage.parse_id('marry/had/a/little/lamb').must_equal(
        environment_permalink: "marry",
        project_permalink: "had",
        deploy_group_permalink: "a",
        key: "little/lamb"
      )
    end

    it "ignores missing parts" do
      SecretStorage.parse_id('').must_equal(
        environment_permalink: nil,
        project_permalink: nil,
        deploy_group_permalink: nil,
        key: nil
      )
    end
  end

  describe ".generate_id" do
    it "generates a private ud" do
      SecretStorage.generate_id(
        environment_permalink: 'production',
        project_permalink: 'foo',
        deploy_group_permalink: 'bar',
        key: 'snafu'
      ).must_equal("production/foo/bar/snafu")
    end

    it "fails raises when missing ids" do
      assert_raises KeyError do
        SecretStorage.generate_id({})
      end
    end
  end

  describe ".read" do
    it "reads" do
      data = SecretStorage.read(secret.id, include_value: true)
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

  describe ".exist?" do
    it "is true when when it exists" do
      SecretStorage.exist?(secret.id).must_equal true
    end

    it "is false on unknown" do
      SecretStorage.exist?('sdfsfsf').must_equal false
    end

    it "is false when backend returns no values" do
      SecretStorage.backend.expects(:read_multi).returns({})
      SecretStorage.exist?('sdfsfsf').must_equal false
    end

    it "is false when backend returns nil values" do
      SecretStorage.backend.expects(:read_multi).returns(foo: nil)
      SecretStorage.exist?('sdfsfsf').must_equal false
    end
  end

  describe ".read_multi" do
    it "reads" do
      data = SecretStorage.read_multi([secret.id], include_value: true)
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
    before { secret }

    it "deletes" do
      SecretStorage.delete(secret.id)
      refute SecretStorage::DbBackend::Secret.exists?(secret.id)
    end

    it "updates ids cache" do
      SecretStorage.ids.must_equal([secret.id]) # fill and check cache
      SecretStorage.backend.expects(:ids).never # block call

      SecretStorage.delete(secret.id)
      SecretStorage.ids.must_equal []
    end

    it "does not cache when cache did not exist" do
      SecretStorage.backend.expects(:ids).never # block call
      SecretStorage.delete(secret.id)
      Rails.cache.read(SecretStorage::SECRET_IDS_CACHE).must_be_nil
    end
  end

  describe ".ids" do
    it "lists ids" do
      secret # trigger creation
      SecretStorage.ids.must_equal ['production/foo/pod2/hello']
    end

    it "is cached" do
      SecretStorage.ids
      secret # trigger creation
      SecretStorage.ids.must_equal []
    end
  end

  describe ".shareable_keys" do
    it "only lists global keys" do
      create_secret 'production/foo/pod2/foo'
      create_secret 'production/global/pod2/bar'
      create_secret 'production/global/pod2/baz'
      SecretStorage.shareable_keys.must_equal ['bar', 'baz']
    end
  end

  describe ".filter_ids_by_value" do
    it "filters keys" do
      id = secret.id
      SecretStorage.filter_ids_by_value([id], 'NOPE').must_equal []
      SecretStorage.filter_ids_by_value([id], secret.value).must_equal [id]
    end
  end

  describe ".sharing_grants?" do
    it "is true when sharing is disabled" do
      refute SecretStorage.sharing_grants?
    end

    it "is false when sharing is enabled" do
      with_env SECRET_STORAGE_SHARING_GRANTS: 'true' do
        assert SecretStorage.sharing_grants?
      end
    end
  end
end
