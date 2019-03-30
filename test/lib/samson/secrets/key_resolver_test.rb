# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::KeyResolver do
  let(:project) { projects(:test) }
  let(:deploy_group) { deploy_groups(:pod1) }
  let(:resolver) { Samson::Secrets::KeyResolver.new(project, [deploy_group]) }
  let(:errors) { resolver.instance_variable_get(:@errors) }

  describe "#expand" do
    before { create_secret("global/global/global/bar") }

    it "expands" do
      resolver.expand('ABC', 'bar').must_equal [["ABC", "global/global/global/bar"]]
    end

    it "reuses project grants" do
      # pretend everything is preloaded
      resolver
      project.secret_sharing_grants
      deploy_group.environment

      assert_sql_queries(0) { resolver.expand('ABC', 'bar') }
    end

    it "expands symbols" do
      resolver.expand(:ABC, 'bar').must_equal [["ABC", "global/global/global/bar"]]
    end

    it "does nothing when not finding a key" do
      resolver.expand('ABC', 'baz').must_equal []
    end

    it "looks up by specificity" do
      create_secret("global/#{project.permalink}/global/bar")
      resolver.expand('ABC', 'bar').must_equal [["ABC", "global/#{project.permalink}/global/bar"]]
    end

    it "has the correct order of specificity" do
      resolver.expand('ABC', 'baz')
      keys = [
        "production/foo/pod1/baz",
        "global/foo/pod1/baz",
        "production/global/pod1/baz",
        "global/global/pod1/baz",
        "production/foo/global/baz",
        "global/foo/global/baz",
        "production/global/global/baz",
        "global/global/global/baz"
      ]
      resolver.instance_variable_get(:@errors).must_equal(
        ["baz\n  (tried: #{keys.join(", ")})"]
      )
    end

    it "does not find deprecated" do
      Samson::Secrets::Manager.write(
        "global/global/global/bar",
        value: 'dsffd',
        comment: '',
        deprecated_at: Time.now.to_s(:db),
        user_id: users(:admin).id,
        visible: true
      )
      resolver.expand('ABC', 'bar').must_equal []
    end

    describe "wildcards" do
      it "fails when only name has wildcard" do
        resolver.expand('ABC_*', 'ba').must_equal []
        errors.first.must_include "need to both end with"
      end

      it "fails when only secret has wildcard" do
        resolver.expand('ABC', 'ba*').must_equal []
        errors.first.must_include "need to both end with"
      end

      it "expands single wildcard key" do
        resolver.expand('ABC_*', 'ba*').must_equal [["ABC_R", "global/global/global/bar"]]
      end

      it "expands duplicate wildcard key at the right place" do
        create_secret("global/global/global/global_global_global")
        resolver.expand('ABC_*', 'global_glob*').must_equal(
          [["ABC_AL_GLOBAL", "global/global/global/global_global_global"]]
        )
      end

      it "prioritizes ids with the same key" do
        create_secret("global/#{project.permalink}/global/bar")
        resolver.expand('ABC_*', 'ba*').must_equal [["ABC_R", "global/#{project.permalink}/global/bar"]]
      end

      it "finds all matching ids" do
        create_secret("global/global/global/baz")
        resolver.expand('ABC_*', 'ba*').sort.must_equal(
          [
            ["ABC_R", "global/global/global/bar"],
            ["ABC_Z", "global/global/global/baz"]
          ]
        )
      end

      it "fails when no key is found" do
        resolver.expand('ABC_*', 'bax*').must_equal []
        errors.first.must_include "bax*\n  (tried: production/foo/pod1/bax*"
      end
    end

    describe "secret sharing" do
      with_env SECRET_STORAGE_SHARING_GRANTS: 'true'

      it "does not include global by default but gives warning they are ignored" do
        assert Samson::Secrets::Manager.sharing_grants?
        resolver.expand('ABC', 'bar').must_equal []
        resolver.instance_variable_get(:@errors).first.must_equal(
          <<~TEXT.strip
            bar
              (tried: production/foo/pod1/bar, global/foo/pod1/bar, production/foo/global/bar, global/foo/global/bar)
              (ignored: global secrets global/global/global/bar add a secret sharing grant to use them)
          TEXT
        )
      end

      it "caches shared keys" do
        resolver.expand('ABC', 'bar').must_equal []
        assert_sql_queries 0 do
          resolver.expand('ABC', 'foo').must_equal []
        end
      end

      it "includes globals when allowed" do
        SecretSharingGrant.create!(project: project, key: 'bar')
        resolver.expand('ABC', 'bar').must_equal [["ABC", "global/global/global/bar"]]
      end
    end
  end

  describe "#read" do
    it "reads secrets" do
      create_secret "global/global/global/foobar"
      resolver.read("foobar").must_equal "MY-SECRET"
      errors.must_equal []
    end

    it "returns nil when it fails to read secrets" do
      Samson::Secrets::Manager.expects(:read_multi).never
      resolver.read("foobar").must_be_nil
      errors.first.must_include "foobar\n  (tried"
    end
  end

  describe "#verify!" do
    it "does nothing when clean" do
      resolver.verify!
    end

    it "raises all errors for easy debugging" do
      resolver.expand('ABC', 'xxx')
      resolver.expand('ABC', 'yyy')
      e = assert_raises Samson::Hooks::UserError do
        resolver.verify!
      end
      e.message.must_include 'xxx'
      e.message.must_include 'yyy'
    end
  end

  describe "#resolved_attribute" do
    let(:deploy) { deploys(:succeeded_test) }
    let(:resolver) { Samson::Secrets::KeyResolver.new(deploy.project, []) }

    it 'resolves the secret' do
      create_secret "global/global/global/rollbar_read_token", value: 'super secret value'

      deploy.reference = "secret://rollbar_read_token"
      resolver.resolved_attribute(deploy.reference).must_equal 'super secret value'
    end

    it 'defaults to attribute value if value doesnt match secret prefix' do
      deploy.reference = '1234Foo'
      resolver.resolved_attribute(deploy.reference).must_equal '1234Foo'
    end
  end
end
