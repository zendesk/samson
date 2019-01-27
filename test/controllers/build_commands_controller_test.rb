# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe BuildCommandsController do
  let(:project) { projects(:test) }
  let(:command) { Command.create(command: 'foo') }

  as_a :viewer do
    unauthorized :patch, :update, project_id: :foo

    describe '#show' do
      it "is renders" do
        get :show, params: {project_id: :foo}
        assert_response :success
      end
    end
  end

  as_a :project_admin do
    describe '#update' do
      it "creates when it does not exist" do
        assert_difference 'Command.count', +1 do
          patch :update, params: {project_id: project, command: {command: 'hello'}}
          assert_redirected_to "/projects/#{project.to_param}/builds"
        end
        project.reload
        project.build_command.command.must_equal 'hello'
        project.build_command.project.must_equal project
      end

      describe "with existing build command" do
        before { project.update_column(:build_command_id, command.id) }

        it "updates when it does already exist" do
          refute_difference 'Command.count' do
            patch :update, params: {project_id: project, command: {command: "bar\r\nfoo"}}
            assert_redirected_to "/projects/#{project.to_param}/builds"
          end
          project.reload.build_command.command.must_equal "bar\r\nfoo"
        end

        it "deletes when blank" do
          assert_difference 'Command.count', -1 do
            patch :update, params: {project_id: project, command: {command: '   '}}
            assert_redirected_to "/projects/#{project.to_param}/builds"
          end
          project.reload.build_command.must_equal nil
        end
      end

      # It isn't possible through the UI to associate a build command with multiple projects.
      # However, it is possible through the API and the console to do this. So in the case that
      # this does happen, we should prevent such commands from being destroyed.
      describe "with reused build command" do
        let(:other_project) do
          p = project.dup
          p.name = 'xxxxx'
          p.permalink = 'xxxxx'
          p.save!(validate: false)
          p
        end

        before do
          project.update_column(:build_command_id, command.id)
          other_project.update_column(:build_command_id, command.id)
        end

        it "does not delete when blank" do
          assert_no_difference 'Command.count' do
            assert_raises(ActiveRecord::RecordNotDestroyed) do
              patch :update, params: {project_id: project, command: {command: '   '}}
            end
          end
          project.reload.build_command.must_equal nil
        end
      end
    end
  end
end
