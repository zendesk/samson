# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud::ImageTagger do
  let(:deploy) { deploys(:succeeded_test) }
  let(:build) { builds(:docker_build) }

  describe ".tag" do
    def tag
      SamsonGcloud::ImageTagger.tag(deploy)
    end

    with_env DOCKER_FEATURE: 'true', GCLOUD_PROJECT: '123', GCLOUD_ACCOUNT: 'acc'

    let(:auth_options) { ['--account', 'acc', '--project', '123'] }

    before do
      build.update_columns(
        git_sha: deploy.commit,
        project_id: deploy.project_id,
        docker_repo_digest: 'gcr.io/sdfsfsdf@some-sha'
      )
    end

    it "tags" do
      Samson::CommandExecutor.expects(:execute).with(
        'gcloud', 'container', 'images', 'add-tag', 'gcr.io/sdfsfsdf@some-sha', 'gcr.io/sdfsfsdf:staging',
        '--quiet', *auth_options, anything
      ).returns([true, "OUT"])
      tag
      deploy.job.output.must_include "\nOUT\nSUCCESS"
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
      deploy.job.output.must_include "NOPE"
    end

    it "includes options from ENV var" do
      with_env(GCLOUD_OPTIONS: '--foo "bar baz"') do
        Samson::CommandExecutor.expects(:execute).with(
          'gcloud', 'container', 'images', 'add-tag', 'gcr.io/sdfsfsdf@some-sha', 'gcr.io/sdfsfsdf:staging',
          '--quiet', '--foo', 'bar baz', *auth_options, anything
        ).returns([true, "OUT"])
        tag
      end
    end
  end
end
