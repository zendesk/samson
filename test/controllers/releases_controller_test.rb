require_relative '../test_helper'

describe ReleasesController do
  describe "#create" do
    as_a_deployer do
      it "creates a new release" do
        project = projects(:test)
        release_params = { commit: "abcd" }

        count = Release.count

        post :create, project_id: project.id, release: release_params

        assert_equal count + 1, Release.count
      end
    end
  end
end
