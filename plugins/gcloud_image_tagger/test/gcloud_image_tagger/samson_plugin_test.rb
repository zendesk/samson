# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloudImageTagger::Engine do
  let(:deploy) { deploys(:succeeded_test) }
  let(:build) { builds(:docker_build) }

  describe ".tag" do
    def expect_version_check(version)
      Samson::CommandExecutor.expects(:execute).with("gcloud", "--version", anything).returns([true, version])
    end

    def tag
      SamsonGcloudImageTagger::Engine.tag(deploy)
    end

    with_env DOCKER_FEATURE: 'true'

    before do
      build.update_columns(
        git_sha: deploy.commit,
        project_id: deploy.project_id,
        docker_repo_digest: 'gcr.io/sdfsfsdf@some-sha'
      )
      SamsonGcloudImageTagger::Engine.class_variable_set(:@@container_in_beta, nil)
    end

    it "tags" do
      expect_version_check("")
      Samson::CommandExecutor.expects(:execute).with(
        'gcloud', 'container', 'images', 'add-tag', 'gcr.io/sdfsfsdf@some-sha', 'gcr.io/sdfsfsdf:staging',
        anything, anything
      ).returns([true, "OUT"])
      tag
      deploy.job.output.must_include "\nOUT\nSUCCESS"
    end

    it "tags other regions" do
      build.update_column(:docker_repo_digest, 'asia.gcr.io/sdfsfsdf@some-sha')
      Samson::CommandExecutor.expects(:execute).twice.returns([true, "OUT"])
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
      Samson::CommandExecutor.expects(:execute).twice.returns([true, "VERSION"], [false, "NOPE"])
      tag
      deploy.job.output.must_include "NOPE"
    end

    it "tags with beta when containers are in beta" do
      expect_version_check("Google Cloud SDK 145.12")
      Samson::CommandExecutor.expects(:execute).with(
        'gcloud', 'beta', 'container', 'images', 'add-tag', anything, anything, anything, anything, anything
      ).returns([true, "OUT"])
      tag
    end
  end

  describe :after_deploy do
    it "tags" do
      SamsonGcloudImageTagger::Engine.expects(:tag)
      Samson::Hooks.fire(:after_deploy, deploy, deploy.user)
    end
  end
end
