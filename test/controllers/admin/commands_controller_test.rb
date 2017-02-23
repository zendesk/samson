# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Admin::CommandsController do
  let(:project) { projects(:test) }
  let(:other_project) do
    p = project.dup
    p.name = 'xxxxx'
    p.permalink = 'xxxxx'
    p.save!(validate: false)
    p
  end

  as_a_viewer do
    command_id = ActiveRecord::FixtureSet.identify(:echo)
    command_params = {command: 'foo', project_id: ActiveRecord::FixtureSet.identify(:test)}
    unauthorized :post, :create, command: command_params
    unauthorized :put, :update, id: command_id, command: command_params
    unauthorized :delete, :destroy, id: command_id

    describe '#index' do
      let(:echo) { commands(:echo) }
      let(:global) { commands(:global) }

      it 'renders template' do
        get :index
        assert_template :index
        assigns[:commands].sort_by(&:id).must_equal [global, echo].sort_by(&:id)
      end

      it 'can filter by words' do
        get :index, params: {search: {query: 'echo'}}
        assigns[:commands].must_equal [echo]
      end

      it 'can filter by project_id' do
        get :index, params: {search: {project_id: echo.project_id}}
        assigns[:commands].must_equal [echo]
      end

      it 'can filter by global' do
        get :index, params: {search: {project_id: 'global'}}
        assigns[:commands].must_equal [global]
      end
    end

    describe '#show' do
      it 'renders' do
        get :show, params: {id: commands(:global).id}
        assert_template :show
      end
    end

    describe '#new' do
      it 'renders' do
        get :new
        assert_template :show
      end
    end
  end

  as_a_project_admin do
    describe "#create" do
      let(:params) { {command: {command: 'hello', project_id: project.id}} }

      it "can create a command for an allowed project" do
        post :create, params: params
        flash[:notice].wont_be_nil
        assert_redirected_to admin_commands_path
      end

      it "fails for invalid command" do
        params[:command][:command] = ""
        post :create, params: params
        assert_template :show
      end

      it "cannot create for a global project" do
        params[:command][:project_id] = ""
        post :create, params: params
        assert_response :unauthorized
      end
    end

    describe '#update' do
      let(:params) { {id: commands(:echo).id, command: {command: 'echo hi', project_id: project.id} } }

      it "can update html" do
        patch :update, params: params
        assert_redirected_to admin_commands_path
        flash[:notice].wont_be_nil
      end

      it "can update as json" do
        patch :update, params: params, format: 'json'
        assert_response :ok
      end

      it "cannot update global" do
        params[:id] = commands(:global).id
        patch :update, params: params
        assert_response :unauthorized
      end

      describe "moving projects" do
        before { params[:command][:project_id] = other_project.id }

        it "cannot update when not admin of both" do
          patch :update, params: params
          assert_response :unauthorized
        end

        it "can update when admin of both" do
          UserProjectRole.create!(role_id: Role::ADMIN.id, project: other_project, user: user)
          patch :update, params: params
          assert_redirected_to admin_commands_path
        end
      end

      describe "invalid" do
        before { params[:command][:command] = "" }

        it "cannot update invalid as html" do
          patch :update, params: params
          assert_template :show
        end

        it "cannot update invalid as json" do
          patch :update, params: params, format: 'json'
          assert_response :unprocessable_entity
        end
      end
    end

    describe "#destroy" do
      it "can delete command for an allowed project" do
        delete :destroy, params: {id: commands(:echo)}
        assert_redirected_to admin_commands_path
      end

      it "cannot delete global commands" do
        delete :destroy, params: {id: commands(:global)}
        assert_response :unauthorized
      end
    end
  end

  as_a_admin do
    describe "#create" do
      it "cannot create for a global project" do
        post :create, params: {command: {command: "hello"}}
        assert_redirected_to admin_commands_path
      end
    end

    describe '#update' do
      it "updates a project" do
        put :update, params: {id: commands(:echo).id, command: { command: 'echo hi', project_id: other_project.id }}
        assert_redirected_to admin_commands_path
      end

      it "updates a global commands" do
        put :update, params: {id: commands(:global).id, command: { command: 'echo hi' }}
        assert_redirected_to admin_commands_path
      end
    end

    describe '#destroy' do
      it "fails with unknown id" do
        assert_raises ActiveRecord::RecordNotFound do
          delete :destroy, params: {id: 123123}
        end
      end

      describe 'valid' do
        before { delete :destroy, params: {id: commands(:echo).id, format: format } }

        describe 'html' do
          let(:format) { 'html' }

          it 'redirects' do
            flash[:notice].wont_be_nil
            assert_redirected_to admin_commands_path
          end

          it 'removes the command' do
            Command.exists?(commands(:echo).id).must_equal(false)
          end
        end

        describe 'json' do
          let(:format) { 'json' }

          it 'responds ok' do
            assert_response :ok
          end
        end
      end
    end
  end
end
