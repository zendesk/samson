require_relative '../../test_helper'

describe Admin::LocksController do
  as_a_deployer do
    unauthorized :post, :create, project_id: 1, stage_id: 1
    unauthorized :delete, :destroy, project_id: 1, stage_id: 1, id: 1
  end

  as_a_admin do
    let(:project) { stage.project }
    let(:stage) { stages(:test_staging) }

    describe 'POST to #create' do
      before { post :create }

      it 'creates a global lock' do
        Lock.global.exists?.must_equal(true)
      end

      it 'redirects' do
        assert_redirected_to admin_projects_path
      end
    end

    describe 'DELETE to #destroy' do
      describe 'without a lock' do
        before { delete :destroy }

        it 'redirects' do
          assert_redirected_to admin_projects_path
        end
      end

      describe 'with a lock' do
        before do
          Lock.create!(user: users(:admin))
          delete :destroy
        end

        it 'removes the lock' do
          Lock.global.must_be_empty
        end

        it 'redirects' do
          assert_redirected_to admin_projects_path
        end
      end
    end
  end
end
