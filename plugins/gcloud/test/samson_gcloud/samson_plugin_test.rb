# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud do
  describe :after_deploy do
    let(:deploy) { deploys(:succeeded_test) }

    it "tags" do
      with_env GCLOUD_IMG_TAGGER: 'true' do
        SamsonGcloud::ImageTagger.expects(:tag)
        Samson::Hooks.fire(:after_deploy, deploy, deploy.user)
      end
    end
  end

  describe :project_permitted_params do
    it "adds build_with_gcb" do
      Samson::Hooks.fire(:project_permitted_params).must_include :build_with_gcb
    end
  end

  describe ".container_in_beta" do
    def expect_version_check(version)
      Samson::CommandExecutor.expects(:execute).with("gcloud", "--version", anything).returns([true, version])
    end

    before { SamsonGcloud.class_variable_set(:@@container_in_beta, nil) }

    it "is nil when not in beta" do
      expect_version_check("Google Cloud SDK 151")
      SamsonGcloud.container_in_beta.must_equal []
    end

    it "is beta when in beta" do
      expect_version_check("Google Cloud SDK 145.12")
      SamsonGcloud.container_in_beta.must_equal ["beta"]
    end
  end
end
