require_relative "../../test_helper"

describe Kubernetes::ReleaseGroup do
  let(:build)  { builds(:docker_build) }
  let(:user)   { users(:deployer) }
  let(:release_group) { Kubernetes::ReleaseGroup.new(build: build, user: user) }

  describe 'validations' do
    it 'asserts image is in registry' do
      release_group.build = builds(:staging)    # does not have a docker image pushed
      refute_valid(release_group, :build)
    end

    it 'asserts there is at least one release' do
      refute_valid(release_group, :releases)
      release_group.deploy_group_ids = [deploy_groups(:pod1).id]
      assert_valid(release_group)
    end
  end

  describe 'deploy_group_ids' do
    let(:group_list) { [deploy_groups(:pod1), deploy_groups(:pod2)] }

    it 'creates releases when deploy_groups are specified' do
      release_group.releases.count.must_equal 0

      release_group.deploy_group_ids = group_list.map(&:id)
      release_group.releases.to_a.count.must_equal 2
      release_group.deploy_group_ids.must_equal group_list.map(&:id)

      release_group.deploy_group_ids = []
      release_group.releases.to_a.count.must_equal 0
    end

    it 'ignores empty strings' do
      group_params = group_list.map(&:id).map(&:to_s)
      group_params << ''

      release_group.deploy_group_ids = group_params
      release_group.releases.to_a.count.must_equal 2
      release_group.deploy_group_ids.must_equal group_list.map(&:id)
    end
  end
end
