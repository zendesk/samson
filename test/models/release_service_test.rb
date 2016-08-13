# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ReleaseService do
  let(:project) { projects(:test) }
  let(:author) { users(:deployer) }
  let(:service) { ReleaseService.new(project) }
  let(:commit) { "abcd" }
  let(:release_params_used) { [] }

  before do
    GITHUB.stubs(:create_release).capture(release_params_used)
  end

  it "creates a new release" do
    count = Release.count

    service.create_release!(commit: commit, author: author)

    assert_equal count + 1, Release.count
  end

  it "tags the release" do
    service.create_release!(commit: commit, author: author)
    assert_equal [[project.github_repo, 'v124', target_commitish: commit]], release_params_used
  end

  it "deploys the commit to stages if they're configured to" do
    stage = project.stages.create!(name: "production", deploy_on_release: true)
    release = service.create_release!(commit: commit, author: author)

    assert_equal release.version, stage.deploys.first.reference
  end

  context 'with release_deploy_conditions hook' do
    let!(:stage) { project.stages.create!(name: "production", deploy_on_release: true) }

    it 'does not deploy if the release_deploy_condition check is false' do
      deployable_condition_check = lambda { |_, _| false }

      Samson::Hooks.with_callback(:release_deploy_conditions, deployable_condition_check) do |_|
        service.create_release!(commit: commit, author: author)

        assert_equal nil, stage.deploys.first
      end
    end

    it 'does deploy if the release_deploy_condition check is true' do
      deployable_condition_check = lambda { |_, _| true }

      Samson::Hooks.with_callback(:release_deploy_conditions, deployable_condition_check) do |_|
        release = service.create_release!(commit: commit, author: author)

        assert_equal release.version, stage.deploys.first.reference
      end
    end
  end
end
