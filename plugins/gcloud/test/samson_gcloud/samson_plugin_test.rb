# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud do
  describe :after_deploy do
    let(:deploy) { deploys(:succeeded_test) }

    it "tags" do
      with_env GCLOUD_IMAGE_TAGGER: 'true' do
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

  describe ".cli_options" do
    it "includes options from ENV var" do
      with_env(GCLOUD_ACCOUNT: 'acc', GCLOUD_PROJECT: 'proj', GCLOUD_OPTIONS: '--foo "bar baz"') do
        SamsonGcloud.cli_options.must_equal ['--foo', 'bar baz', '--account', 'acc', '--project', 'proj']
      end
    end

    it "does not include options from ENV var when not set" do
      with_env(GCLOUD_ACCOUNT: 'acc', GCLOUD_PROJECT: 'proj') do
        SamsonGcloud.cli_options.must_equal ['--account', 'acc', '--project', 'proj']
      end
    end
  end

  describe ".project" do
    it "fetches" do
      with_env GCLOUD_PROJECT: '123' do
        SamsonGcloud.project.must_equal "123"
      end
    end

    it "cannot be used to hijack commands" do
      with_env GCLOUD_PROJECT: '123; foo' do
        SamsonGcloud.project.must_equal "123\\;\\ foo"
      end
    end

    it "fails when not set since it would break commands" do
      assert_raises(KeyError) { SamsonGcloud.project }
    end
  end

  describe ".account" do
    it "fetches" do
      with_env GCLOUD_ACCOUNT: '123' do
        SamsonGcloud.account.must_equal "123"
      end
    end

    it "cannot be used to hijack commands" do
      with_env GCLOUD_ACCOUNT: '123; foo' do
        SamsonGcloud.account.must_equal "123\\;\\ foo"
      end
    end

    it "fails when not set since it would break commands" do
      assert_raises(KeyError) { SamsonGcloud.account }
    end
  end
end
