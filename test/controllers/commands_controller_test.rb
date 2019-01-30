# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe CommandsController do
  let(:project) { projects(:test) }
  let(:other_project) do
    p = project.dup
    p.name = 'xxxxx'
    p.permalink = 'xxxxx'
    p.save!(validate: false)
    p
  end

  as_a :viewer do
    command_id = ActiveRecord::FixtureSet.identify(:echo)
    command_params = {command: 'foo', project_id: ActiveRecord::FixtureSet.identify(:test)}
    unauthorized :post, :create, command: command_params
    unauthorized :put, :update, id: command_id, command: command_params
    unauthorized :delete, :destroy, id: command_id

    describe '#index' do
      let(:hello) { commands(:echo) }
      let(:global) { commands(:global) }

      it 'renders template' do
        get :index
        assert_template :index
        assigns[:commands].sort_by(&:id).must_equal [global, hello].sort_by(&:id)
      end

      it 'can filter by words' do
        get :index, params: {search: {query: 'hello'}}
        assigns[:commands].must_equal [hello]
      end

      it 'can filter by project_id' do
        get :index, params: {search: {project_id: hello.project_id}}
        assigns[:commands].must_equal [hello]
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
        assert_template :new
      end
    end
  end

  as_a :project_admin do
    describe "#create" do
      let(:params) { {command: {command: 'hello', project_id: project.id}} }

      it "can create a command for an allowed project" do
        post :create, params: params
        flash[:notice].wont_be_nil
        assert_redirected_to command_path(Command.last)
      end

      it "fails for invalid command" do
        params[:command][:command] = ""
        post :create, params: params
        assert_template :new
      end

      it "cannot create for a global project" do
        params[:command][:project_id] = ""
        post :create, params: params
        assert_response :unauthorized
      end
    end

    describe '#update' do
      let(:command) { commands(:echo) }
      let(:params) { {id: command.id, command: {command: 'echo hi', project_id: project.id}} }

      it "can update html" do
        patch :update, params: params
        assert_redirected_to command
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

      it "can update when not changing project" do
        params[:command].delete(:project_id)
        patch :update, params: params
        assert_response :redirect
        command.reload.project.wont_be_nil
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
          assert_redirected_to command
        end
      end

      describe "invalid" do
        before { params[:command][:command] = "" }

        it "cannot update invalid as html" do
          patch :update, params: params
          assert_template :edit
        end

        it "cannot update invalid as json" do
          patch :update, params: params, format: 'json'
          assert_response :unprocessable_entity
        end
      end
    end

    describe "#destroy" do
      before { StageCommand.delete_all }

      it "can delete command for an allowed project" do
        delete :destroy, params: {id: commands(:echo)}
        assert_redirected_to commands_path
      end

      it "cannot delete global commands" do
        delete :destroy, params: {id: commands(:global)}
        assert_response :unauthorized
      end
    end
  end

  as_a :admin do
    describe "#create" do
      it "cannot create for a global project" do
        post :create, params: {command: {command: "hello"}}
        assert_redirected_to command_path(Command.last)
      end
    end

    describe '#update' do
      it "updates a project" do
        command = commands(:echo)
        put :update, params: {id: command.id, command: {command: 'echo hi', project_id: other_project.id}}
        assert_redirected_to command_path(command)
      end

      it "updates a global commands" do
        command = commands(:global)
        put :update, params: {id: command.id, command: {command: 'echo hi'}}
        assert_redirected_to command_path(command)
      end
    end

    describe '#destroy' do
      let(:command) { commands(:echo) }

      it "fails with unknown id" do
        assert_raises ActiveRecord::RecordNotFound do
          delete :destroy, params: {id: 123123}
        end
      end

      describe 'valid' do
        describe 'html' do
          let(:format) { 'html' }

          def delete_command(param_overrides = {})
            params = {id: command.id, format: format}.merge(param_overrides)
            delete :destroy, params: params
          end

          it 'redirects' do
            StageCommand.delete_all

            delete_command

            assert flash[:notice]
            assert_redirected_to commands_path
          end

          it 'removes the command' do
            StageCommand.delete_all

            delete_command

            Command.exists?(command.id).must_equal(false)
          end

          describe 'delete from stage edit' do
            it 'removes stage command and command if stage is passed' do
              stage = stages(:test_staging)
              stage_command = stage_commands(:test_staging_echo)

              command.stage_commands = [stage_command]

              assert_difference 'StageCommand.count', -1 do
                assert_difference 'Command.count', -1 do
                  delete_command(stage_id: stage.id)
                end
              end

              StageCommand.exists?(stage_command.id).must_equal false
              Command.exists?(command.id).must_equal false
            end

            it 'removes stage command but not command if stage is passed but command is still in use elsewhere' do
              stage_command_id = stage_commands(:test_staging_echo).id

              assert_difference 'StageCommand.count', -1 do
                assert_no_difference 'Command.count' do
                  delete_command(stage_id: stages(:test_staging).id)
                end
              end

              StageCommand.exists?(stage_command_id).must_equal false
              Command.exists?(command.id).must_equal true
            end

            it 'removes command without stage command (command deselected)' do
              StageCommand.delete_all

              delete_command(stage_id: stages(:test_staging).id)

              Command.exists?(command.id).must_equal(false)
            end
          end
        end

        describe 'json' do
          let(:format) { 'json' }

          it 'responds ok' do
            assert_response :ok
          end
        end
      end

      describe 'invalid' do
        before { delete :destroy, params: {id: command.id, format: format} }

        describe 'html' do
          let(:format) { 'html' }

          it 'fails' do
            Command.exists?(command.id).must_equal(true)
            assert_redirected_to command
            assert flash[:alert]
          end
        end

        describe 'json' do
          let(:format) { 'json' }

          it 'responds ok' do
            assert_response :unprocessable_entity
          end
        end
      end
    end
  end
end
