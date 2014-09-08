require_relative '../test_helper'

describe StagesController do
  subject { stages(:test_staging) }

  as_a_deployer do
    describe 'GET to :show' do
      describe 'valid' do
        before do
          get :show, project_id: subject.project.to_param,
            id: subject.id
        end

        it 'renders the template' do
          assert_template :show
        end
      end

      describe 'invalid project' do
        before do
          get :show, project_id: 123123,
            id: subject.id
        end

        it 'redirects' do
          assert_redirected_to root_path
        end
      end

      describe 'invalid stage' do
        before do
          get :show, project_id: subject.project.to_param,
            id: 123123
        end

        it 'redirects' do
          assert_redirected_to project_path(subject.project)
        end
      end
    end

    unauthorized :get, :new, project_id: 1
    unauthorized :post, :create, project_id: 1
    unauthorized :get, :edit, project_id: 1, id: 1
    unauthorized :patch, :update, project_id: 1, id: 1
    unauthorized :delete, :destroy, project_id: 1, id: 1
  end

  as_a_admin do
    describe 'GET to #new' do
      describe 'valid' do
        before { get :new, project_id: subject.project.to_param }

        it 'renders' do
          assert_template :new
        end

        it 'adds global commands by default' do
          assigns(:stage).command_ids.wont_be_empty
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
        subject { assigns(:stage) }

        before do
          new_command = Command.create!(
            command: 'test2 command'
          )

          post :create, project_id: project.to_param, stage: {
            name: 'test',
            command: 'test command',
            command_ids: [commands(:echo).id, new_command.id]
          }

          subject.reload
          subject.commands.reload
        end

        it 'is created' do
          subject.persisted?.must_equal(true)
          subject.command_ids.must_include(commands(:echo).id)
          subject.command.must_equal(commands(:echo).command + "\ntest2 command\ntest command")
        end

        it 'redirects' do
          assert_redirected_to project_stage_path(project, assigns(:stage))
        end
      end

      describe 'invalid attributes' do
        before do
          post :create, project_id: project.to_param, stage: {
            name: nil
          }
        end

        it 'renders' do
          assert_template :new
        end
      end

      describe 'invalid project id' do
        before do
          post :create, project_id: 123123
        end

        it 'redirects' do
          assert_redirected_to root_path
        end
      end
    end

    describe 'GET to #edit' do
      describe 'valid' do
        before { get :edit, project_id: subject.project.to_param, id: subject.id }

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
        before { get :edit, project_id: subject.project.to_param, id: 123123 }

        it 'redirects' do
          assert_redirected_to project_path(subject.project)
        end
      end
    end

    describe 'PATCH to #update' do
      describe 'valid id' do
        before do
          patch :update, project_id: subject.project.to_param, id: subject.id,
            stage: attributes

          subject.reload
        end

        describe 'valid attributes' do
          let(:attributes) {{
            command: 'test command',
            name: 'Hello'
          }}

          it 'updates name' do
            subject.name.must_equal('Hello')
          end

          it 'redirects' do
            assert_redirected_to project_stage_path(subject.project, subject)
          end

          it 'adds a command' do
            command = subject.commands.reload.last
            command.command.must_equal('test command')
          end
        end

        describe 'invalid attributes' do
          let(:attributes) {{ name: nil }}

          it 'renders' do
            assert_template :edit
          end
        end
      end

      describe 'invalid project_id' do
        before { patch :update, project_id: 123123, id: 1 }

        it 'redirects' do
          assert_redirected_to root_path
        end
      end

      describe 'invalid id' do
        before { patch :update, project_id: subject.project.to_param, id: 123123 }

        it 'redirects' do
          assert_redirected_to project_path(subject.project)
        end
      end
    end

    describe 'DELETE to #destroy' do
      describe 'valid' do
        before { delete :destroy, project_id: subject.project.to_param, id: subject.id }

        it 'redirects' do
          assert_redirected_to project_path(subject.project)
        end

        it 'removes stage' do
          subject.reload
          subject.deleted_at.wont_be_nil
        end
      end

      describe 'invalid project_id' do
        before { delete :destroy, project_id: 123123, id: 1 }

        it 'redirects' do
          assert_redirected_to root_path
        end
      end

      describe 'invalid id' do
        before { delete :destroy, project_id: subject.project.to_param, id: 123123 }

        it 'redirects' do
          assert_redirected_to project_path(subject.project)
        end
      end

    end

    describe 'GET to #clone' do
      before { get :clone, project_id: subject.project.to_param, id: subject.id }

      it 'renders :new' do
        assert_template :new
      end
    end
  end
end
