require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::JobsController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:admin) { users(:admin) }
  let(:build) { builds(:docker_build) }
  let(:task)  { kubernetes_tasks(:db_migrate) }
  let(:job) do
    Kubernetes::Job.create!(
      stage: stage, kubernetes_task: task, build: build,
      commit: build.git_sha, tag: build.git_ref, user: admin
    )
  end
  let(:job_service) { stub(run!: nil) }
  let(:execute_called) { [] }

  before { kubernetes_fake_job_raw_template }

  as_a_viewer do
    describe "a GET to :index" do
      before do
        get :index,
          project_id: project.to_param,
          kubernetes_task_id: task.id
      end

      it "renders the template" do
        assert_template :index
      end
    end

    describe "a GET to :show" do
      describe 'with a job' do
        before do
          get :show,
            project_id: project.to_param,
            kubernetes_task_id: task.id,
            id: job
        end

        it "renders the template" do
          assert_template :show
        end
      end

      describe 'with a running job' do
        before do
          get :show,
            project_id: project.to_param,
            kubernetes_task_id: task.id,
            id: kubernetes_jobs(:running_test)
        end

        it "renders the template" do
          assert_template :show
        end
      end

      it "fails with unknown job" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, project_id: project.to_param, kubernetes_task_id: task.id, id: "job:nope"
        end
      end

      describe "with format .text" do
        before { get :show, format: :text, project_id: project.to_param, kubernetes_task_id: task.id, id: job }

        it "responds with a plain text file" do
          assert_equal response.content_type, "text/plain"
        end

        it "responds with a .log file" do
          assert response.header["Content-Disposition"] =~ /\.log"$/
        end
      end
    end

    unauthorized :post, :create, project_id: :foo
  end

  as_a_deployer do
    unauthorized :post, :create, project_id: :foo
  end

  as_a_project_admin do
    describe "#new" do
      it "renders" do
        get :new, project_id: project, kubernetes_task_id: task.id
        assert_template :new
      end
    end

    describe "#create" do
      let(:job_params) { { "stage_id" => stage.id.to_param, "commit" => "master" } }

      before do
        Kubernetes::JobService.stubs(:new).returns(job_service)
        job_service.stubs(:run!).capture(execute_called)
        JobExecution.stubs(:start_job)

        post :create, kubernetes_job: job_params, project_id: project.to_param, kubernetes_task_id: task.id
      end

      it "redirects to the job path" do
        assert_redirected_to project_kubernetes_job_path(project, Kubernetes::Job.last, kubernetes_task_id: task.id)
      end

      it "creates a job" do
        assert_equal [[]], execute_called
      end

      describe "when invalid" do
        let(:job_params) { { "stage_id" => '', "commit" => "master" } }

        it "renders" do
          assert_template :new
        end
      end
    end
  end
end
