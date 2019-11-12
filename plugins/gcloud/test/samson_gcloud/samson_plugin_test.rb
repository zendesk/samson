# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud do
  describe :after_deploy do
    let(:deploy) { deploys(:succeeded_test) }

    it "tags" do
      with_env GCLOUD_IMAGE_TAGGER: 'true' do
        SamsonGcloud::ImageTagger.expects(:tag)
        Samson::Hooks.fire(:after_deploy, deploy, stub(output: nil))
      end
    end

    it "does not tag when disabled" do
      SamsonGcloud::ImageTagger.expects(:tag).never
      Samson::Hooks.fire(:after_deploy, deploy, stub(output: nil))
    end
  end

  describe :resolve_docker_image_tag do
    it "resolves the tag" do
      SamsonGcloud::TagResolver.expects(:resolve_docker_image_tag).returns "bar"
      with_env GCLOUD_PROJECT: "foo" do
        Samson::Hooks.fire(:resolve_docker_image_tag, "foo").must_include "bar"
      end
    end

    it "does not resolve when not configured" do
      Samson::Hooks.fire(:resolve_docker_image_tag, "foo").must_equal [nil]
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

  describe ".gcr?" do
    it "knows when on gcr" do
      assert SamsonGcloud.gcr?("gcr.io/foo")
      assert SamsonGcloud.gcr?("https://gcr.io/foo")
      assert SamsonGcloud.gcr?("foo.gcr.io/foo")
    end

    it "knows when not on gcr" do
      refute SamsonGcloud.gcr?("gcrio/foo")
      refute SamsonGcloud.gcr?("gomicloud.io/foo")
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
