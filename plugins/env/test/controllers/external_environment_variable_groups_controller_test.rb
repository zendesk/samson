# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe ExternalEnvironmentVariableGroupsController do
  with_env EXTERNAL_ENV_GROUP_S3_REGION: "us-east-1", EXTERNAL_ENV_GROUP_S3_BUCKET: "a-bucket"

  let(:project) { projects(:test) }
  let(:group) do
    ExternalEnvironmentVariableGroup.create!(
      name: "A",
      description: "B",
      url: "https://a-bucket.s3.amazonaws.com/key?versionId=version_id",
      project: project
    )
  end

  as_a :viewer do
    describe "#preview" do
      before do
        ExternalEnvironmentVariableGroup.any_instance.stubs(:read).returns("a" => "b")
      end

      it "renders" do
        get :preview, params: {id: group.id}
        assert_response :success
      end

      it "renders fake group" do
        get :preview, params: {id: "fake", url: "foo"}
        assert_response :success
      end

      describe "a json GET to #index" do
        it "succeeds" do
          get :index, format: :json
          assert_response :success
          json_response = JSON.parse response.body
          json_response.keys.must_include 'groups'
        end
      end

      describe "a json GET to #preview" do
        it "succeeds" do
          get :preview, params: {id: group.id}, format: :json
          assert_response :success
          json_response = JSON.parse response.body
          json_response['group'].must_equal JSON.parse(group.to_json)
          json_response['data'].must_equal("a" => "b")
        end

        it "fails when env group is unknown" do
          ExternalEnvironmentVariableGroup.any_instance.unstub(:read)
          assert_raises ActiveRecord::RecordNotFound do
            get :preview, params: {id: "00"}, format: :json
          end
        end
      end
    end
  end
end
