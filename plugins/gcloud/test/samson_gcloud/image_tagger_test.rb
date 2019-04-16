# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud::ImageTagger do
  let(:deploy) { deploys(:succeeded_production_test) }
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
    let(:output_serialized) { output.messages.gsub(/\[.*?\] /, "[TIME] ") }

    before do
      build.update_columns(
        git_sha: deploy.commit,
        project_id: deploy.project_id,
        docker_repo_digest: 'gcr.io/sdfsfsdf@some-sha'
      )
    end

    it "tags" do
      assert_tagged_with 'production'
      tag
      output_serialized.must_include "OUT"
      output_serialized.must_include "[TIME] Tagging GCR image:\n"
    end

    it 'does not tag if stage does not deploy code' do
      deploy.stage.update_column(:no_code_deployed, true)
      tag
      output_serialized.must_equal ""
    end

    it "does not tag when already tagged" do
      assert_tagged_with 'production'
      2.times { tag }
      output_serialized.scan(/OUT/).size.must_equal 1
    end

    it "tries again when tagging failed" do
      Samson::CommandExecutor.expects(:execute).returns([false, 'x']).times(2)
      2.times { tag }
    end

    it 'does not tag non-prod' do
      Stage.any_instance.expects(:production?).returns(false)
      tag
      output_serialized.must_equal ""
    end

    it 'does not tag without DOCKER_FEATURE' do
      with_env DOCKER_FEATURE: nil do
        tag
        output_serialized.must_equal ""
      end
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
        assert_tagged_with 'production', opts: ['--foo', 'bar baz']
        tag
      end
    end
  end
end
