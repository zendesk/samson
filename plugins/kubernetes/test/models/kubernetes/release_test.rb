require_relative "../../test_helper"

describe Kubernetes::Release do
  let(:build)  { builds(:docker_build) }
  let(:user)   { users(:deployer) }
  let(:release) { Kubernetes::Release.new(build: build, user: user) }

  describe 'validations' do
    it 'asserts image is in registry' do
      release.build = builds(:staging)    # does not have a docker image pushed
      refute_valid(release, :build)
    end
  end

  describe 'validations' do
    it 'is valid by default' do
      assert_valid(release)
    end

    it 'test validity of status' do
      Kubernetes::Release::STATUSES.each do |status|
        assert_valid(release.tap { |kr| kr.status = status })
      end
      refute_valid(release.tap { |kr| kr.status = 'foo' })
      refute_valid(release.tap { |kr| kr.status = nil })
    end
  end
end

