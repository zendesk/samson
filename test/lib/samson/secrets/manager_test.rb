# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::Manager do
  def create_sercret_with_cache_bypass
    Samson::Secrets::DbBackend::Secret.create!(
      id: 'production/foo/pod2/hello',
      value: 'MY-SECRET',
      visible: false,
      comment: 'this is secret',
      updater_id: users(:admin).id,
      creator_id: users(:admin).id
    )
  end

  let(:secret) { create_secret 'production/foo/pod2/hello' }

  describe ".allowed_project_prefixes" do
    it "is all for admin" do
      Samson::Secrets::Manager.allowed_project_prefixes(users(:admin)).must_equal ['global'] +
        Project.pluck(:permalink).sort
    end

    it "is allowed for project admin" do
      Samson::Secrets::Manager.allowed_project_prefixes(users(:project_admin)).must_equal ['foo']
    end
  end

  describe ".write" do
    let(:attributes) do
      {value: '111', user_id: users(:admin).id, visible: false, comment: 'comment', deprecated_at: nil}
    end

    it "writes" do
      id = 'production/foo/pod2/hello'
      Samson::Secrets::Manager.write(id, attributes).must_equal true
      secret = Samson::Secrets::DbBackend::Secret.find(id)
      secret.value.must_equal '111'
      secret.creator_id.must_equal users(:admin).id
      secret.updater_id.must_equal users(:admin).id
    end

    it "adds id to ids cache" do
      secret # create
      Samson::Secrets::Manager.ids.must_equal([secret.id]) # fill and check cache
      Samson::Secrets::Manager.backend.expects(:ids).never # block call

      id = 'production/foo/pod2/world'
      Samson::Secrets::Manager.write(id, attributes).must_equal true
      Samson::Secrets::Manager.ids.sort.must_equal [secret.id, id]
    end

    it "writes to cache when cache is empty" do
      secret # create
      Rails.cache.clear

      id = 'production/foo/pod2/world'
      Samson::Secrets::Manager.write(id, attributes).must_equal true
      Samson::Secrets::Manager.ids.sort.must_equal [secret.id, id]
    end

    it "does not add known id to ids cache" do
      secret # create
      Samson::Secrets::Manager.ids.must_equal([secret.id]) # fill and check cache
      Samson::Secrets::Manager.backend.expects(:ids).never # block call

      Samson::Secrets::Manager.write(secret.id, attributes).must_equal true
      Samson::Secrets::Manager.ids.sort.must_equal [secret.id]
    end

    it "refuses to write empty ids" do
      Samson::Secrets::Manager.write('', attributes).must_equal false
    end

    it "refuses to write ids with spaces" do
      Samson::Secrets::Manager.write('  production/foo/pod2/hello', attributes).must_equal false
    end

    it "refuses to write empty values" do
      Samson::Secrets::Manager.write('production/foo/pod2/hello', attributes.merge(value: '   ')).must_equal false
    end

    it "refuses to write ids we will not be able to replace in commands" do
      Samson::Secrets::Manager.write('a"b', attributes).must_equal false
    end
  end

  describe ".parse_id" do
    it "parses parts" do
      Samson::Secrets::Manager.parse_id('marry/had/a/little/lamb').must_equal(
        environment_permalink: "marry",
        project_permalink: "had",
        deploy_group_permalink: "a",
        key: "little/lamb"
      )
    end

    it "ignores missing parts" do
      Samson::Secrets::Manager.parse_id('').must_equal(
        environment_permalink: nil,
        project_permalink: nil,
        deploy_group_permalink: nil,
        key: nil
      )
    end
  end

  describe ".generate_id" do
    it "generates a private ud" do
      Samson::Secrets::Manager.generate_id(
        environment_permalink: 'production',
        project_permalink: 'foo',
        deploy_group_permalink: 'bar',
        key: 'snafu'
      ).must_equal("production/foo/bar/snafu")
    end

    it "fails raises when missing ids" do
      assert_raises KeyError do
        Samson::Secrets::Manager.generate_id({})
      end
    end
  end

  describe ".read" do
    it "reads" do
      data = Samson::Secrets::Manager.read(secret.id, include_value: true)
      data.fetch(:value).must_equal 'MY-SECRET'
    end

    it "does not read secrets by default" do
      data = Samson::Secrets::Manager.read(secret.id)
      refute data.key?(:value)
    end

    it "raises on unknown" do
      assert_raises ActiveRecord::RecordNotFound do
        Samson::Secrets::Manager.read('dfsfsfdsdf')
      end
    end
  end

  describe ".history" do
    it "reads values" do
      data = Samson::Secrets::Manager.history(secret.id, include_value: true)
      data.fetch(:versions).values.map { |v| v.fetch(:value) }.must_equal ["v1", "v2", "v2", "v3"]
    end

    it "reads diff" do
      data = Samson::Secrets::Manager.history(secret.id)
      data.fetch(:versions).values.map { |v| v.fetch(:value) }.
        must_equal ["(changed)", "(changed)", "(unchanged)", "(changed)"]
    end
  end

  describe ".revert" do
    it "reverts a secret to an older version" do
      Samson::Secrets::Manager.revert(secret.id, to: "v2", user: users(:project_admin))
      current = Samson::Secrets::Manager.read(secret.id, include_value: true)
      current[:value].must_equal "MY-SECRET"
      current[:updater_id].must_equal users(:project_admin).id
    end
  end

  describe ".move" do
    def move(deprecate)
      Samson::Secrets::Manager.move "global/foo/global/bar", "global/baz/global/bar", deprecate: deprecate
    end

    before do
      create_secret "global/foo/global/bar" # create
      create_secret "global/foo/global/bar", user_id: users(:deployer).id # update
    end

    it "moves and cleanes up the old" do
      old = Samson::Secrets::Manager.read "global/foo/global/bar", include_value: true

      move false

      moved = Samson::Secrets::Manager.read("global/baz/global/bar", include_value: true)
      moved.except(:updated_at, :created_at).must_equal(old.except(:updated_at, :created_at))
      refute Samson::Secrets::Manager.exist?("global/foo/global/bar")
    end

    it "fails when target exists" do
      create_secret "global/baz/global/bar"
      e = assert_raises { move false }
      e.message.must_equal "global/baz/global/bar already exists"
    end

    it "moves with deprecation" do
      move true

      assert Samson::Secrets::Manager.exist?("global/baz/global/bar")
      assert Samson::Secrets::Manager.exist?("global/foo/global/bar")
      assert Samson::Secrets::Manager.read("global/foo/global/bar")[:deprecated_at]
    end
  end

  describe ".rename_project" do
    it "copies secrets and tells user how many were copied" do
      create_secret "global/bar/global/bar" # create a bogus secret to make sure we filter
      secret # trigger creation
      Samson::Secrets::Manager.rename_project("foo", "baz").must_equal 1
      assert Samson::Secrets::Manager.read('production/foo/pod2/hello')
      assert Samson::Secrets::Manager.read('production/baz/pod2/hello')
    end
  end

  describe ".copy_project" do
    it "copies secrets and tells user how many were copied" do
      create_secret "global/bar/pod2/bar" # should not touch other projects
      create_secret "global/foo/pod1/bar" # should not touch other deploy groups

      secret # trigger creation of foo/pod2 secret
      Samson::Secrets::Manager.copy_project("foo", "pod2", "pod3").must_equal 1
      assert Samson::Secrets::Manager.read('production/foo/pod2/hello') # original exists
      assert Samson::Secrets::Manager.read('production/foo/pod3/hello') # copied exists
    end
  end

  describe ".exist?" do
    it "is true when when it exists" do
      Samson::Secrets::Manager.exist?(secret.id).must_equal true
    end

    it "is false on unknown" do
      Samson::Secrets::Manager.exist?('sdfsfsf').must_equal false
    end

    it "is false when backend returns no values" do
      Samson::Secrets::Manager.backend.expects(:read_multi).returns({})
      Samson::Secrets::Manager.exist?('sdfsfsf').must_equal false
    end

    it "is false when backend returns nil values" do
      Samson::Secrets::Manager.backend.expects(:read_multi).returns(foo: nil)
      Samson::Secrets::Manager.exist?('sdfsfsf').must_equal false
    end
  end

  describe ".read_multi" do
    it "reads" do
      data = Samson::Secrets::Manager.read_multi([secret.id], include_value: true)
      data.keys.must_equal [secret.id]
      data[secret.id].fetch(:value).must_equal 'MY-SECRET'
    end

    it "does not read secrets by default" do
      data = Samson::Secrets::Manager.read_multi([secret.id])
      refute data[secret.id].key?(:value)
    end

    it "returns empty for unknown" do
      Samson::Secrets::Manager.read_multi([secret.id, 'dfsfsfdsdf']).keys.must_equal [secret.id]
      Samson::Secrets::Manager.read_multi(['dfsfsfdsdf']).keys.must_equal []
    end
  end

  describe ".delete" do
    before { secret }

    it "deletes" do
      Samson::Secrets::Manager.delete(secret.id)
      refute Samson::Secrets::DbBackend::Secret.exists?(secret.id)
    end

    it "updates ids cache" do
      Samson::Secrets::Manager.ids.must_equal([secret.id]) # fill and check cache
      Samson::Secrets::Manager.backend.expects(:ids).never # block call

      Samson::Secrets::Manager.delete(secret.id)
      Samson::Secrets::Manager.ids.must_equal []
    end

    it "caches when cache did not exist" do
      Samson::Secrets::Manager.backend.expects(:ids).never # block call
      Samson::Secrets::Manager.delete(secret.id)
      Samson::Secrets::Manager.send(:cache).read(Samson::Secrets::Manager::SECRET_LOOKUP_CACHE).must_equal({})
    end
  end

  describe ".ids" do
    let(:secret) { create_sercret_with_cache_bypass }

    it "lists ids" do
      secret # trigger creation
      Samson::Secrets::Manager.ids.must_equal ['production/foo/pod2/hello']
    end

    it "is cached" do
      Samson::Secrets::Manager.ids
      secret # trigger creation
      Samson::Secrets::Manager.ids.must_equal []
    end

    it "can cache things that are too big for memcache" do
      secret # trigger creation
      Samson::Secrets::Manager.expects(:lookup_cache_value).returns('a' * 10_000_000)
      Samson::Secrets::Manager.ids.size.must_equal 1
      Rails.cache.instance_variable_get(:@data).values.last.value.to_s.size.must_be :<, 1_000_000
    end
  end

  describe ".shareable_keys" do
    it "only lists global keys" do
      create_secret 'production/foo/pod2/foo'
      create_secret 'production/global/pod2/baz'
      create_secret 'production/global/pod2/bar'
      create_secret 'production/global/pod3/bar'
      Samson::Secrets::Manager.shareable_keys.must_equal ['bar', 'baz']
    end
  end

  describe ".filter_ids_by_value" do
    it "filters keys" do
      id = secret.id
      Samson::Secrets::Manager.filter_ids_by_value([id], 'NOPE').must_equal []
      Samson::Secrets::Manager.filter_ids_by_value([id], secret.value).must_equal [id]
    end
  end

  describe ".sharing_grants?" do
    it "is true when sharing is disabled" do
      refute Samson::Secrets::Manager.sharing_grants?
    end

    it "is false when sharing is enabled" do
      with_env SECRET_STORAGE_SHARING_GRANTS: 'true' do
        assert Samson::Secrets::Manager.sharing_grants?
      end
    end
  end

  describe ".expire_lookup_cache" do
    it "expires the cache" do
      Samson::Secrets::Manager.ids

      create_sercret_with_cache_bypass
      Samson::Secrets::Manager.ids.must_equal []

      Samson::Secrets::Manager.expire_lookup_cache
      Samson::Secrets::Manager.ids.must_equal ["production/foo/pod2/hello"]
    end
  end
end
