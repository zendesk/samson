# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe BuildCommandsController do
  let(:project) { projects(:test) }

  as_a_viewer do
    unauthorized :patch, :update, project_id: :foo

    describe '#show' do
      it "is renders" do
        get :show, params: {project_id: :foo}
        assert_response :success
      end
    end
  end

  as_a_project_admin do
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
        before { project.update_column(:build_command_id, Command.create(command: 'foo').id) }

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
    end
  end
end
