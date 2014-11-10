require_relative '../test_helper'
require 'timecop'

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

  describe "#index" do
    as_a_viewer do
      let (:from) { 2.days.ago }
      let (:to) { 10.minutes.ago }

      let (:old_release) do
        project.create_release(author_type: "User", author_id: 1, commit: "master")
      end

      let (:new_release) do
        project.create_release(author_type: "User", author_id: 1, commit: "master")
      end

      before do
        Timecop.freeze(1.day.ago)
        old_release
        Timecop.return
        new_release
      end

      it "searches by date" do
        get :index, format: :json, project_id: project.to_param, from: from.strftime("%F"), to: to.strftime("%F")
        assert_equal response.body, ["v1"].to_json
      end

      it "returns all releases when no dates are passed " do
        get :index, format: :json, project_id: project.to_param
        assert_equal response.body, ["v2", "v1"].to_json
      end
    end
  end
end
