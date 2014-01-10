require_relative '../test_helper'

describe StagesController do
  subject { stages(:test_staging) }

  as_a_deployer do
    describe 'GET to :show' do
      describe 'valid' do
        before do
          get :show, :project_id => subject.project_id,
            :id => subject.id
        end

        it 'renders the template' do
          assert_template :show
        end
      end

      describe 'invalid project' do
        before do
          get :show, :project_id => 123123,
            :id => subject.id
        end

        it 'redirects' do
          assert_redirected_to root_path
        end
      end

      describe 'invalid stage' do
        before do
          get :show, :project_id => subject.project_id,
            :id => 123123
        end

        it 'redirects' do
          assert_redirected_to project_path(subject.project)
        end
      end
    end

    unauthorized :get, :new, project_id: 1
    unauthorized :post, :create, project_id: 1
    unauthorized :get, :edit, project_id: 1, id: 1
    unauthorized :delete, :destroy, project_id: 1, id: 1
  end

  as_a_admin do
    describe 'GET to #new' do
      describe 'valid' do
        before { get :new, project_id: subject.project_id }

        it 'renders' do
          assert_template :new
        end
      end

      describe 'invalid project_id' do
        before { get :new, project_id: 123123 }

        it 'redirects' do
          assert_redirected_to root_path
        end
      end
    end

    describe 'POST to #create' do
      let(:project) { projects(:test) }

      describe 'valid' do
        before do
          post :create, :project_id => project.id, :stage => {
            :name => 'test',
            :command_ids => [commands(:echo).id]
          }
        end

        it 'is created' do
          assigns(:stage).persisted?.must_equal(true)
          assigns(:stage).command_ids.must_equal([commands(:echo).id])
        end

        it 'redirects' do
          assert_redirected_to project_stage_path(project, assigns(:stage))
        end
      end

      describe 'invalid attributes' do
        before do
          post :create, :project_id => project.id, :stage => {
            :name => nil
          }
        end

        it 'renders' do
          assert_template :new
        end
      end

      describe 'invalid project id' do
        before do
          post :create, :project_id => 123123
        end

        it 'redirects' do
          assert_redirected_to root_path
        end
      end
    end

    describe 'GET to #edit' do
      describe 'valid' do
        before { get :edit, project_id: subject.project_id, id: subject.id }

        it 'renders' do
          assert_template :edit
        end
      end

      describe 'invalid project_id' do
        before { get :edit, project_id: 123123, id: 1 }

        it 'redirects' do
          assert_redirected_to root_path
        end
      end

      describe 'invalid id' do
        before { get :edit, project_id: subject.project_id, id: 123123 }

        it 'redirects' do
          assert_redirected_to project_path(subject.project)
        end
      end
    end

    describe 'DELETE to #destroy' do
      describe 'valid' do
        before { delete :destroy, project_id: subject.project_id, id: subject.id }

        it 'redirects' do
          assert_redirected_to project_path(subject.project)
        end

        it 'removes stage' do
          Stage.exists?(subject.id).must_equal(false)
        end
      end

      describe 'invalid project_id' do
        before { delete :destroy, project_id: 123123, id: 1 }

        it 'redirects' do
          assert_redirected_to root_path
        end
      end

      describe 'invalid id' do
        before { delete :destroy, project_id: subject.project_id, id: 123123 }

        it 'redirects' do
          assert_redirected_to project_path(subject.project)
        end
      end
    end
  end
end
