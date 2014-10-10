require_relative '../test_helper'

describe ReleasesController do
  let(:project) { projects(:test) }

  describe "#create" do
    let(:release_params) { { commit: "abcd" } }

    as_a_viewer do
      it "doesn't creates a new release" do
        count = Release.count
        post :create, project_id: project.to_param, release: release_params
        assert_equal count, Release.count
      end
    end

    as_a_deployer do
      it "creates a new release" do
        count = Release.count
        post :create, project_id: project.to_param, release: release_params
        assert_equal count + 1, Release.count
      end
    end
  end
end
