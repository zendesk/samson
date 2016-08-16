# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Secrets::KeyResolver do
  let(:project) { projects(:test) }
  let(:deploy_group) { deploy_groups(:pod1) }
  let(:resolver) { Samson::Secrets::KeyResolver.new(project, [deploy_group]) }

  describe "#expand!" do
    before { SecretStorage.write("global/global/global/bar", value: 'something', user_id: 123) }

    it "expands" do
      key = 'secret/bar'.dup
      resolver.expand!(key)
      key.must_equal "global/global/global/bar"
    end

    it "does nothing when not finding a key" do
      key = 'secret/baz'.dup
      resolver.expand!(key)
      key.must_equal "secret/baz"
    end

    it "looks up by specificity" do
      SecretStorage.write("global/#{project.permalink}/global/bar", value: 'something', user_id: 123)
      key = 'secret/bar'.dup
      resolver.expand!(key)
      key.must_equal "global/#{project.permalink}/global/bar"
    end

    it "has the correct order of specificity" do
      key = 'secret/baz'.dup
      resolver.expand!(key)
      resolver.instance_variable_get(:@errors).must_equal([
        "secret/baz (tried: production/foo/pod1/baz, global/foo/pod1/baz, production/global/pod1/baz, global/global/pod1/baz, production/foo/global/baz, global/foo/global/baz, production/global/global/baz, global/global/global/baz)"
      ])
    end
  end

  describe "#verify!" do
    it "does nothing when clean" do
      resolver.verify!
    end

    it "raises all errors for easy debugging" do
      resolver.expand!('secret/xxx')
      resolver.expand!('secret/yyy')
      e = assert_raises Samson::Hooks::UserError do
        resolver.verify!
      end
      e.message.must_include 'xxx'
      e.message.must_include 'yyy'
    end
  end
end
