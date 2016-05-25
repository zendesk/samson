require_relative '../test_helper'

SingleCov.covered!

describe JobsController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:admin) { users(:admin) }
  let(:command) { "echo hello" }
  let(:job) { Job.create!(command: command, project: project, user: admin) }
  let(:job_service) { stub(execute!: nil) }
  let(:execute_called) { [] }

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
    describe "a GET to :index" do
      before { get :index, project_id: project.to_param }

      it "renders the template" do
        assert_template :index
      end
    end

    describe "a GET to :show" do
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
      before do
        JobService.stubs(:new).with(project, user).returns(job_service)
        job_service.stubs(:execute!).capture(execute_called).returns(job)
        JobExecution.stubs(:start_job)

        post :create, commands: {ids: []}, job: {
          command: command,
          commit: "master"
        }, project_id: project.to_param
      end

      it "redirects to the job path" do
        assert_redirected_to project_job_path(project, job)
      end

      it "creates a job" do
        assert_equal [["master", [], command]], execute_called
      end

      describe "when invalid" do
        let("job") { Job.new }

        it "renders" do
          assert_template :new
        end
      end
    end

    describe "a DELETE to :destroy" do
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
