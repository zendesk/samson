# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ReleaseService do
  let(:project) { projects(:test) }
  let(:service) { ReleaseService.new(project) }

  describe "#release" do
    def assert_failed_ref_find(count)
      GITHUB.unstub(:release_for_tag)
      project.repository.expects(:commit_from_ref).times(count).returns(nil)
      Samson::Retry.expects(:sleep).times(count - 1)
      assert_raises RuntimeError do
        service.release(commit: commit, author: author)
      end
    end

    let(:author) { users(:deployer) }
    let(:commit) { "abcd" * 10 }
    let(:release_params_used) { [] }

    before do
      GITHUB.stubs(:create_release).capture(release_params_used)
      project.repository.stubs(:commit_from_ref).returns("abc")
      project.repository.stubs(:commit_from_ref).returns("abc")
      GitRepository.any_instance.expects(:fuzzy_tag_from_ref).returns(nil)
    end

    it "creates a new release" do
      assert_difference "Release.count", +1 do
        service.release(commit: commit, author: author)
      end
    end

    it "does nothing when release failed validation" do
      GitRepository.any_instance.unstub(:fuzzy_tag_from_ref)
      assert_difference "Release.count", 0 do
        Release.any_instance.expects(:save).returns(false)
        service.release(commit: commit, author: author)
      end
    end

    it "tags the release" do
      service.release(commit: commit, author: author)
      assert_equal [[project.repository_path, 'v124', target_commitish: commit]], release_params_used
    end

    it "stops when release cannot be found" do
      assert_failed_ref_find 4
    end

    it "can configure numbers of retries" do
      with_env RELEASE_TAG_IN_REPO_RETRIES: "10" do
        assert_failed_ref_find 10
      end
    end

    it "deploys the commit to stages if they're configured to" do
      stage = project.stages.create!(name: "release", deploy_on_release: true)
      release = service.release(commit: commit, author: author)

      assert_equal release.version, stage.deploys.first.reference
    end

    context 'with release_deploy_conditions hook' do
      let!(:stage) { project.stages.create!(name: "release", deploy_on_release: true) }

      it 'does not deploy if the release_deploy_condition check is false' do
        deployable_condition_check = ->(_, _) { false }

        Samson::Hooks.with_callback(:release_deploy_conditions, deployable_condition_check) do |_|
          service.release(commit: commit, author: author)

          stage.deploys.first.must_be_nil
        end
      end

      it 'does deploy if the release_deploy_condition check is true' do
        deployable_condition_check = ->(_, _) { true }

        Samson::Hooks.with_callback(:release_deploy_conditions, deployable_condition_check) do |_|
          release = service.release(commit: commit, author: author)

          assert_equal release.version, stage.deploys.first.reference
        end
      end
    end
  end

  describe "#can_release?" do
    it "can release when it can create tags" do
      stub_github_api("repos/bar/foo", permissions: {push: true})
      assert service.can_release?
    end

    it "cannot release when it cannot create tags" do
      stub_github_api("repos/bar/foo", permissions: {push: false})
      refute service.can_release?
    end

    it "cannot release when user is unauthorized" do
      stub_github_api("repos/bar/foo", {}, 401)
      refute service.can_release?
    end

    it "cannot release when user does not have github access" do
      stub_github_api("repos/bar/foo", {}, 404)
      refute service.can_release?
    end
  end
end
