# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 2

describe SamsonGcloud::ImageTagger do
  let(:deploy) { deploys(:succeeded_test) }
  let(:build) { builds(:docker_build) }

  describe ".tag" do
    def tag
      SamsonGcloud::ImageTagger.tag(deploy, output)
    end

    def assert_tagged_with(tag, opts: [])
      Samson::CommandExecutor.expects(:execute).with(
        'gcloud', 'container', 'images', 'add-tag', 'gcr.io/sdfsfsdf@some-sha', "gcr.io/sdfsfsdf:#{tag}",
        '--quiet', *opts, *auth_options, anything
      ).returns([true, "OUT"])
    end

    with_env DOCKER_FEATURE: 'true', GCLOUD_PROJECT: '123', GCLOUD_ACCOUNT: 'acc'

    let(:auth_options) { ['--account', 'acc', '--project', '123'] }
    let(:output) { OutputBuffer.new }
    let(:output_serialized) { output.messages.gsub(/\[.*?\] /, "") }

    before do
      build.update_columns(
        git_sha: deploy.commit,
        project_id: deploy.project_id,
        docker_repo_digest: 'gcr.io/sdfsfsdf@some-sha'
      )
    end

    it "tags" do
      assert_tagged_with 'stage-staging'
      tag
      output_serialized.must_include "\nOUT"
    end

    it 'includes timestamp' do
      assert_tagged_with 'stage-staging'
      tag
      output_serialized.must_include "Tagging GCR image:\n"
    end

    it 'does not tag with invalid stage permalink' do
      deploy.stage.update_column(:permalink, '%$!')
      tag
    end

    it 'tags with environment permalink' do
      with_env DEPLOY_GROUP_FEATURE: 'true' do
        deploy.stage.environments.first.update_column(:permalink, 'muchstaging')

        assert_tagged_with 'env-muchstaging'
        assert_tagged_with 'stage-staging'

        tag

        output_serialized.must_include "\nOUT"
      end
    end

    it 'does not tag with invalid environment permalink' do
      with_env DEPLOY_GROUP_FEATURE: 'true' do
        deploy.stage.environments.first.update_column(:permalink, '%$!')

        assert_tagged_with 'stage-staging'

        tag
      end
    end

    it 'tags with production if stage is production' do
      deploy.stage.expects(:production?).returns(true)

      assert_tagged_with 'production'
      assert_tagged_with 'stage-staging'

      deploy.stage.permalink.wont_equal 'production'

      tag

      output_serialized.must_include "\nOUT"
    end

    it 'does not tag with production if stage does not deploy code' do
      deploy.stage.update_column(:no_code_deployed, true)
      deploy.stage.expects(:production?).returns(true)

      assert_tagged_with 'stage-staging'

      tag

      output_serialized.must_include "\nOUT"
    end

    it "tags other regions" do
      build.update_column(:docker_repo_digest, 'asia.gcr.io/sdfsfsdf@some-sha')
      Samson::CommandExecutor.expects(:execute).returns([true, "OUT"])
      tag
    end

    it "does not tag on failed deploys" do
      deploy.job.update_column(:status, 'cancelled')
      Samson::CommandExecutor.expects(:execute).never
      tag
    end

    it "does not tag non-gcr images" do
      build.update_column(:docker_repo_digest, 'something.else@sha')
      Samson::CommandExecutor.expects(:execute).never
      tag
    end

    it "shows tagging errors" do
      Samson::CommandExecutor.expects(:execute).returns([false, "NOPE"])
      tag
      output_serialized.must_include "NOPE"
    end

    it "includes options from ENV var" do
      with_env(GCLOUD_OPTIONS: '--foo "bar baz"') do
        assert_tagged_with 'stage-staging', opts: ['--foo', 'bar baz']
        tag
      end
    end
  end
end
