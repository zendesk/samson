# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe MacrosController do
  let(:project) { projects(:test) }
  let(:macro) { macros(:test) }
  let(:job) { Job.create!(commit: macro.reference, command: macro.script, project: project, user: user) }

  as_a_viewer do
    unauthorized :get, :index, project_id: :foo
    unauthorized :get, :new, project_id: :foo
    unauthorized :get, :edit, project_id: :foo, id: 1
    unauthorized :post, :create, project_id: :foo
    unauthorized :post, :execute, project_id: :foo, id: 1
    unauthorized :put, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_project_deployer do
    describe "#index" do
      before { get :index, params: {project_id: project.to_param } }

      it "renders the template" do
        assert_template :index
      end
    end

    describe '#execute' do
      it "executes a macro" do
        JobExecution.expects(:start_job)
        assert_difference 'Job.count' do
          post :execute, params: {project_id: project.to_param, id: macro.id}
        end
        assert_redirected_to project_job_path(project, Job.last)
      end

      it "fails execute an invalid macro" do
        JobExecution.expects(:start_job).never
        Job.any_instance.expects(:save).returns(false)
        refute_difference 'Job.count' do
          post :execute, params: {project_id: project.to_param, id: macro.id}
        end
        assert_redirected_to project_macros_path(project)
      end

      it 'fails for non-existent macro' do
        assert_raises ActiveRecord::RecordNotFound do
          post :execute, params: {project_id: project.to_param, id: 123123123}
        end
      end
    end

    unauthorized :get, :new, project_id: :foo
    unauthorized :get, :edit, project_id: :foo, id: 1
    unauthorized :post, :create, project_id: :foo
    unauthorized :put, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_project_admin do
    describe '#new' do
      before { get :new, params: {project_id: project.to_param } }

      it 'renders the template' do
        assert_template :new
      end
    end

    describe '#edit' do
      describe 'with a macro' do
        before do
          get :edit, params: {project_id: project.to_param, id: macro.id}
        end

        it 'renders the template' do
          assert_template :edit
        end
      end

      it 'fails for non-existent macro' do
        assert_raises ActiveRecord::RecordNotFound do
          get :edit, params: {project_id: project.to_param, id: 123123}
        end
      end
    end

    describe '#create' do
      describe 'with a valid macro' do
        before do
          post :create, params: {
            project_id: project.to_param,
            macro: {
              name: 'Testing',
              reference: 'master',
              command: '/bin/true'
            }
          }
        end

        it 'redirects to the macros path' do
          assert_redirected_to project_macros_path(project)
        end
      end

      describe 'with an invalid macro' do
        before do
          post :create, params: {project_id: project.to_param, macro: {name: 'Testing'}}
        end

        it 'renders the form' do
          assert_template :new
        end
      end
    end

    describe '#update' do
      describe 'with a valid macro' do
        before do
          post :update, params: {project_id: project.to_param, id: macro.id, macro: {name: 'New'}}
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
          post :update, params: {project_id: project.to_param, id: macro.id, macro: {name: ''}}
        end

        it 'renders the correct template' do
          assert_template :edit
        end
      end
    end

    describe '#destroy' do
      before do
        delete :destroy, params: {project_id: project.to_param, id: macro.id}
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
