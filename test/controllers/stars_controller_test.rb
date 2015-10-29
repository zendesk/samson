require_relative '../test_helper'

describe StarsController do
  let(:current_user) { users(:viewer) }
  let(:project) { projects(:test) }

  as_a_viewer do
    describe 'no stars' do
      it 'should create a star' do
        refute current_user.starred_project?(project)
        post :create, id: project.to_param
        assert_response :success
        current_user.reload
        assert current_user.starred_project?(project), 'new star expected'
      end
    end

    describe 'star present' do
      before { current_user.stars.create!(project: project) }

      it 'should delete a star' do
        assert current_user.starred_project?(project)
        delete :destroy, id: project.to_param
        assert_response :success
        current_user.reload
        refute current_user.starred_project?(project), 'no stars expected'
      end
    end
  end
end

