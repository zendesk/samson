# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SecretSharingGrant do
  let(:project) { projects(:test) }
  let(:grant) { SecretSharingGrant.create!(project: project, key: 'foo') }
  let(:other_project) do
    Project.any_instance.stubs(:valid_repository_url).returns(true)
    Project.create!(name: 'Z', repository_url: 'Z')
  end

  describe "validations" do
    it "is valid" do
      assert_valid grant
    end

    it "is valid with different project" do
      assert_valid SecretSharingGrant.new(project: other_project, key: grant.key)
    end

    it "is valid with different key" do
      assert_valid SecretSharingGrant.new(project: project, key: 'bar')
    end

    it "is invvalid with same project and key" do
      other = SecretSharingGrant.new(project: project, key: grant.key)
      refute_valid other
      other.errors.full_messages.must_equal ["Key and project combination already in use"]
    end
  end
end
