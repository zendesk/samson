require_relative '../test_helper'

describe MacrosController do
  let(:project) { projects(:test) }
  let(:macro) { stages(:macro) }
  let(:job) { Job.create!(commit: 'master', command: macro.command, project: project, user: user) }

  as_a_viewer do
    unauthorized :get, :index, project_id: :foo
    unauthorized :get, :new, project_id: :foo
    unauthorized :get, :edit, project_id: :foo, id: 1
    unauthorized :post, :create, project_id: :foo
    unauthorized :put, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_project_deployer do
    describe "a GET to :index" do
      setup { get :index, project_id: project.to_param }

      it "renders the template" do
        assert_template :index
      end
    end

    unauthorized :get, :new, project_id: :foo
    unauthorized :get, :edit, project_id: :foo, id: 1
    unauthorized :post, :create, project_id: :foo
    unauthorized :put, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_project_admin do
    describe 'a GET to #new' do
      before { get :new, project_id: project.to_param }

      it 'renders the template' do
        assert_template :new
      end
    end

    describe 'a GET to #edit' do
      describe 'with a macro' do
        before do
          get :edit, project_id: project.to_param, id: macro.id
        end

        it 'renders the template' do
          assert_template :edit
        end
      end

      it 'fails for non-existent macro' do
        assert_raises ActiveRecord::RecordNotFound do
          get :edit, project_id: project.to_param, id: 123123
        end
      end
    end

    describe 'a POST to #create' do
      describe 'with a valid macro' do
        before do
          post :create, project_id: project.to_param, macro: {
            name: 'Testing',
            command: '/bin/true'
          }
        end

        it 'redirects to the macros path' do
          assert_redirected_to project_macros_path(project)
        end
      end

      describe 'with an invalid macro' do
        before do
          post :create, project_id: project.to_param, macro: {name: ''}
        end

        it 'renders the form' do
          assert_template :new
        end
      end
    end

    describe 'a PUT to #update' do
      describe 'with a valid macro' do
        before do
          post :update, project_id: project.to_param, id: macro.id, macro: {name: 'New'}
        end

        it 'updates the macro' do
          macro.reload.name.must_equal('New')
        end

        it 'redirects properly' do
          assert_redirected_to project_macros_path(project)
        end
      end

      describe 'with an invalid macro' do
        before do
          post :update, project_id: project.to_param, id: macro.id, macro: {name: ''}
        end

        it 'renders the correct template' do
          assert_template :edit
        end

        it 'shows errors' do
          assert flash[:error]
        end
      end
    end

    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_super_admin do
    describe 'a DELETE to #destroy' do
      before do
        delete :destroy, project_id: project.to_param, id: macro.id
      end

      it 'soft deletes the macro' do
        lambda { project.macros.find(macro.id) }.must_raise(ActiveRecord::RecordNotFound)
        Macro.unscoped.find(macro.id).must_equal(macro)
      end

      it 'redirects properly' do
        assert_redirected_to project_macros_path(project)
      end
    end
  end
end
