require_relative '../test_helper'

SingleCov.covered!

describe StarsController do
  let(:current_user) { users(:viewer) }
  let(:project) { projects(:test) }

  as_a_viewer do
    describe "#create" do
      before { refute current_user.starred_project?(project) }

      it "creates a star" do
        post :create, id: project.to_param
        assert_response :success
        current_user.reload
        assert current_user.starred_project?(project), 'new star expected'
      end

      it "fails to create a duplicate start" do
        post :create, id: project.to_param
        assert_raises ActiveRecord::RecordNotUnique do
          post :create, id: project.to_param
        end
      end
    end

    describe "#destroy" do
      before { current_user.stars.create!(project: project) }

      it 'deletes a star' do
        delete :destroy, id: project.to_param
        assert_response :success
        current_user.reload
        refute current_user.starred_project?(project), 'no stars expected'
      end

      it 'ignores already deletes stars' do
        delete :destroy, id: project.to_param
        delete :destroy, id: project.to_param
        assert_response :success
      end
    end
  end
end
