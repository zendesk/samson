require_relative '../test_helper'

describe MacrosController do
  let(:project) { projects(:test) }
  let(:deployer) { users(:deployer) }
  let(:macro) { macros(:test) }
  let(:macro_service) { stub(execute!: nil) }
  let(:execute_called) { [] }
  let(:job) { Job.create!(commit: macro.reference, command: macro.command, project: project, user: deployer) }

  setup do
    MacroService.stubs(:new).with(project, deployer).returns(macro_service)
    macro_service.stubs(:execute!).capture(execute_called).returns(job)
  end

  as_a_viewer do
    it 'authorizes correctly' do
      unauthorized :get, :index, project_id: project.id
      unauthorized :get, :new, project_id: project.id
      unauthorized :get, :edit, project_id: project.id, id: 1
      unauthorized :post, :create, project_id: project.id
      unauthorized :post, :execute, project_id: project.id, id: 1
      unauthorized :put, :update, project_id: project.id, id: 1
      unauthorized :delete, :destroy, project_id: project.id, id: 1
    end
  end

  as_a_deployer do
    describe "a GET to :index" do
      setup { get :index, project_id: project.to_param }

      it "renders the template" do
        assert_template :index
      end
    end

    describe 'a POST to #execute' do
      describe 'with a macro' do
        setup do
          JobExecution.stubs(:start_job).with(macro.reference, job)
          post :execute, project_id: project.to_param, id: macro.id
        end

        it "redirects to the job path" do
          assert_redirected_to project_job_path(project, job)
        end

        it "creates a job" do
          assert_equal [[macro]], execute_called
        end
      end

      it 'fails for non-existent macro' do
        assert_raises ActiveRecord::RecordNotFound do
          post :execute, project_id: project.to_param, id: 123123123
        end
      end
    end

    it 'authorizes correctly' do
      unauthorized :get, :new, project_id: project.id
      unauthorized :get, :edit, project_id: project.id, id: 1
      unauthorized :post, :create, project_id: project.id
      unauthorized :put, :update, project_id: project.id, id: 1
      unauthorized :delete, :destroy, project_id: project.id, id: 1
    end
  end

  as_a_admin do
    describe 'a GET to #new' do
      setup { get :new, project_id: project.to_param }

      it 'renders the template' do
        assert_template :new
      end
    end

    describe 'a GET to #edit' do
      describe 'with a macro' do
        setup do
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
        setup do
          post :create, project_id: project.to_param, macro: {
            name: 'Testing',
            reference: 'master',
            command: '/bin/true'
          }
        end

        it 'redirects to the macros path' do
          assert_redirected_to project_macros_path(project)
        end
      end

      describe 'with an invalid macro' do
        setup do
          post :create, project_id: project.to_param, macro: {
            name: 'Testing'
          }
        end

        it 'renders the form' do
          assert_template :new
        end
      end
    end

    describe 'a PUT to #update' do
      describe 'with a valid macro' do
        setup do
          post :update, project_id: project.to_param, id: macro.id, macro: {
            name: 'New'
          }
        end

        it 'updates the macro' do
          macro.reload.name.must_equal('New')
        end

        it 'redirects properly' do
          assert_redirected_to project_macros_path(project)
        end
      end

      describe 'with an invalid macro' do
        setup do
          post :update, project_id: project.to_param, id: macro.id, macro: {
            name: ''
          }
        end

        it 'renders the correct template' do
          assert_template :edit
        end
      end
    end

    describe 'a DELETE to #destroy' do
      describe 'with the macro creator' do
        setup do
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

      describe 'as someone else' do
        setup do
          macro.update_attributes!(user: users(:deployer))
        end

        it 'is unauthorized' do
          unauthorized :delete, :destroy, project_id: project.to_param, id: macro.id
        end
      end
    end
  end

  as_a_super_admin do
    describe 'a DELETE to #destroy' do
      setup do
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
