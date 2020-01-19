# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe ExternalEnvironmentVariableGroupsController do
  before do
    ExternalEnvironmentVariableGroup.any_instance.
      expects(:read).times(2).returns("a" => "b")
  end

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
      it "renders" do
        get :preview, params: {id: group.id}
        assert_response :success
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
