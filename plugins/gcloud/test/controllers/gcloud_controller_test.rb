# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe GcloudController do
  with_env GCLOUD_ACCOUNT: "foo", GCLOUD_PROJECT: "bar"

  as_a :viewer do
    describe "#sync_build" do
      def do_sync
        post :sync_build, params: {id: build.id}
        assert_response :redirect
      end

      let(:build) { builds(:docker_build) }
      let(:gcr_id) { "ee5316fa-5569-aaaa-bbbb-09e0e5b1319a" }
      let(:result) do
        {
          results: {images: [{name: "nope", digest: "bar"}, {name: image_name, digest: sha}]},
          status: "SUCCESS"
        }
      end
      let(:repo_digest) { "#{image_name}@#{sha}" }
      let(:image_name) { "gcr.io/foo/#{build.image_name}" }
      let(:sha) { "sha256:#{"a" * 64}" }

      before do
        build.update_column(:external_url, "https://console.cloud.google.com/gcr/builds/#{gcr_id}?project=foobar")
      end

      it "can sync" do
        Samson::CommandExecutor.expects(:execute).returns([true, result.to_json])
        do_sync
        assert flash[:notice]
        build.reload
        build.docker_repo_digest.must_equal repo_digest
        build.external_status.must_equal "succeeded"
      end

      it "can sync images with a tag" do
        result[:results][:images][1][:name] += ":foo"
        Samson::CommandExecutor.expects(:execute).returns([true, result.to_json])
        do_sync
        build.reload.docker_repo_digest.must_equal repo_digest
      end

      it "fails when gcloud cli fails" do
        Samson::CommandExecutor.expects(:execute).returns([false, result.to_json])
        do_sync
        assert flash[:alert]
      end

      describe "with invalid image name" do
        let(:image_name) { "gcr.io/foo*baz+bing/#{build.image_name}" }

        it "fails when digest does not pass validations" do
          Samson::CommandExecutor.expects(:execute).returns([true, result.to_json])

          do_sync

          assert flash[:alert]
          build.reload.docker_repo_digest.wont_equal repo_digest
        end
      end

      it "fails when image is not found" do
        result[:results][:images].last[:name] = "gcr.io/other"
        Samson::CommandExecutor.expects(:execute).returns([true, result.to_json])

        do_sync

        assert flash[:notice]
        build.reload.docker_repo_digest.wont_equal repo_digest
      end

      it "can store failures" do
        result[:status] = "QUEUED"
        result.delete(:results)
        Samson::CommandExecutor.expects(:execute).returns([true, result.to_json])

        do_sync

        assert flash[:notice]
        build.reload
        build.docker_repo_digest.wont_equal repo_digest
        build.external_status.must_equal "pending"
      end
    end
  end
end
