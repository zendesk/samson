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

    with_env DOCKER_FEATURE: 'true'

    before do
      build.update_columns(
        git_sha: deploy.commit,
        project_id: deploy.project_id,
        docker_repo_digest: 'gcr.io/sdfsfsdf@some-sha'
      )
      SamsonGcloud.stubs(container_in_beta: [])
    end

    it "tags" do
      Samson::CommandExecutor.expects(:execute).with(
        'gcloud', 'container', 'images', 'add-tag', 'gcr.io/sdfsfsdf@some-sha', 'gcr.io/sdfsfsdf:staging',
        anything, anything
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

    it "tags with beta when containers are in beta" do
      SamsonGcloud.stubs(container_in_beta: ['beta'])
      Samson::CommandExecutor.expects(:execute).with(
        'gcloud', 'beta', 'container', 'images', 'add-tag', anything, anything, anything, anything, anything
      ).returns([true, "OUT"])
      tag
    end

    it "includes options from ENV var" do
      with_env(GCLOUD_IMG_TAGGER_OPTS: '--foo "bar baz"') do
        Samson::CommandExecutor.expects(:execute).with(
          'gcloud', 'container', 'images', 'add-tag', 'gcr.io/sdfsfsdf@some-sha', 'gcr.io/sdfsfsdf:staging',
          '--quiet', '--foo', 'bar baz', anything
        ).returns([true, "OUT"])
        tag
      end
    end
  end
end
