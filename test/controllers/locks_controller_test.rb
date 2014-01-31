require_relative '../test_helper'

describe LocksController do
  as_a_viewer do
    unauthorized :post, :create, project_id: 1, stage_id: 1
    unauthorized :delete, :destroy, project_id: 1, stage_id: 1, id: 1
  end

  as_a_deployer do
    let(:project) { stage.project }
    let(:stage) { stages(:test_staging) }

    describe 'POST to #create' do
      describe 'without a project' do
        before { post :create, project_id: 123123, stage_id: 1 }

        it 'redirects' do
          assert_redirected_to root_path
        end
      end

      describe 'with a project' do
        describe' without a stage' do
          before { post :create, project_id: project.id, stage_id: 1 }

          it 'redirects' do
            assert_redirected_to project_path(project)
          end
        end

        describe 'with a stage' do
          before { post :create, project_id: project.id, stage_id: stage.id }

          it 'creates a lock' do
            stage.reload.locked?.must_equal(true)
          end

          it 'redirects' do
            assert_redirected_to project_stage_path(project, stage)
          end
        end
      end
    end

    describe 'DELETE to #destroy' do
      describe 'without a project' do
        before { delete :destroy, project_id: 123123, stage_id: 1 }

        it 'redirects' do
          assert_redirected_to root_path
        end
      end

      describe 'with a project' do
        describe' without a stage' do
          before { delete :destroy, project_id: project.id, stage_id: 1 }

          it 'redirects' do
            assert_redirected_to project_path(project)
          end
        end

        describe 'with a stage' do
          describe 'without a lock' do
            before { delete :destroy, project_id: project.id, stage_id: stage.id }

            it 'redirects' do
              assert_redirected_to project_stage_path(project, stage)
            end
          end

          describe 'with a lock' do
            before do
              stage.create_lock!(user: users(:deployer))
              delete :destroy, project_id: project.id, stage_id: stage.id
            end

            it 'removes the lock' do
              stage.reload.locked?.must_equal(false)
            end
          end
        end
      end
    end
  end
end
