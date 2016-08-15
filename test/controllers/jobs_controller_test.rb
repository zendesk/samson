# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe JobsController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:admin) { users(:admin) }
  let(:command) { "echo hi" }
  let(:job) { Job.create!(command: command, project: project, user: admin) }
  let(:job_service) { stub(execute!: nil) }

  as_a_viewer do
    describe "#enabled" do
      it "is no_content when enabled" do
        JobExecution.expects(:enabled).returns true
        get :enabled
        assert_response :no_content
      end

      it "is accepted when disabled" do
        refute JobExecution.enabled
        get :enabled
        assert_response :accepted
      end
    end
  end

  as_a_viewer do
    describe "#index" do
      before { get :index, project_id: project.to_param }

      it "renders the template" do
        assert_template :index
      end
    end

    describe "#show" do
      describe 'with a job' do
        before { get :show, project_id: project.to_param, id: job }

        it "renders the template" do
          assert_template :show
        end
      end

      describe 'with a running job' do
        before { get :show, project_id: project.to_param, id: jobs(:running_test) }

        it "renders the template" do
          assert_template :show
        end
      end

      it "fails with unknown job" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, project_id: project.to_param, id: "job:nope"
        end
      end

      describe "with format .text" do
        before { get :show, format: :text, project_id: project.to_param, id: job }

        it "responds with a plain text file" do
          assert_equal response.content_type, "text/plain"
        end

        it "responds with a .log file" do
          assert response.header["Content-Disposition"] =~ /\.log"$/
        end
      end
    end

    unauthorized :post, :create, project_id: :foo
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_deployer do
    unauthorized :post, :create, project_id: :foo
    unauthorized :delete, :destroy, project_id: :foo, id: 1
    # FIXME: I should be able to stop my own jobs
  end

  as_a_project_admin do
    describe "#new" do
      it "renders" do
        get :new, project_id: project
        assert_template :new
      end
    end

    describe "#create" do
      let(:command_ids) { [] }

      def create
        post :create, commands: {ids: command_ids}, job: {
          command: command,
          commit: "master"
        }, project_id: project.to_param
      end

      it "creates a job and starts it" do
        JobExecution.expects(:start_job)
        assert_difference('Job.count') { create }
        assert_redirected_to project_job_path(project, Job.last)
      end

      it "keeps commands in correct order" do
        command_ids.replace([commands(:global).id, commands(:echo).id])
        create
        Job.last.command.must_equal("t\necho hello\necho hi")
      end

      it "fails to create job when locked" do
        JobExecution.expects(:start_job).never
        Job.any_instance.expects(:save).returns(false)
        refute_difference('Job.count') { create }
        assert_template :new
      end
    end

    describe "#destroy" do
      describe "when being a admin of the project" do
        before do
          delete :destroy, project_id: project.to_param, id: job
        end

        it "deletes the job" do
          assert_redirected_to [project, job]
          flash.must_be_empty
        end
      end

      describe "when not being an admin of the project" do
        before do
          UserProjectRole.delete_all
          delete :destroy, project_id: project.to_param, id: job
        end

        it "does not delete the job" do
          assert_unauthorized
        end
      end
    end
  end
end
