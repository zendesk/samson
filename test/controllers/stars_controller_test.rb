# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe StarsController do
  let(:current_user) { users(:viewer) }
  let(:project) { projects(:test) }

  as_a :viewer do
    describe "#create" do
      before { refute current_user.starred_project?(project) }

      it "creates a star" do
        post :create, params: {project_id: project.to_param}
        assert_response :success
        current_user.reload
        assert current_user.starred_project?(project)
      end

      it "deletes an existing star" do
        post :create, params: {project_id: project.to_param}
        post :create, params: {project_id: project.to_param}
        assert_response :success
        current_user.reload
        refute current_user.starred_project?(project)
      end
    end
  end
end
