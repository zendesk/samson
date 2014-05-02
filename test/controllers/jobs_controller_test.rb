require_relative '../test_helper'

describe JobsController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:admin) { users(:admin) }
  let(:command) { "echo hello" }
  let(:job) { Job.create!(command: command, project: project, user: admin) }
  let(:job_service) { stub(execute!: nil) }

  setup do
    JobService.stubs(:new).with(project, admin).returns(job_service)
    job_service.stubs(:execute!).returns(job)
  end

  as_a_viewer do
    describe "a GET to :index" do
      setup { get :index, project_id: project.id }

      it "renders the template" do
        assert_template :index
      end
    end

    describe "a GET to :show" do
      describe 'with a job' do
        setup { get :show, project_id: project.id, id: job }

        it "renders the template" do
          assert_template :show
        end
      end

      describe "with no job" do
        setup { get :show, project_id: project.id, id: "job:nope" }

        it "redirects to the root page" do
          assert_redirected_to root_path
        end

        it "sets the flash error" do
          request.flash[:error].wont_be_nil
        end
      end

      describe "with format .text" do
        setup { get :show, format: :text, project_id: project.id, id: job }

        it "responds with a plain text file" do
          assert_equal response.content_type, "text/plain"
        end

        it "responds with a .log file" do
          assert response.header["Content-Disposition"] =~ /\.log"$/
        end
      end
    end

    unauthorized :post, :create, project_id: 1
    unauthorized :delete, :destroy, project_id: 1, id: 1
  end

  as_a_deployer do
    unauthorized :post, :create, project_id: 1
    unauthorized :delete, :destroy, project_id: 1, id: 1
  end

  as_a_admin do
    describe "a POST to :create" do
      setup do
        post :create, commands: { ids: [] }, job: {
          command: command,
          commit: "master"
        }, project_id: project.id
      end

      let(:params) 

      it "redirects to the job path" do
        assert_redirected_to project_job_path(project, job)
      end

      it "creates a job" do
        assert_received(job_service, :execute!) do |expect|
          expect.with "master", [], command
        end
      end
    end
    describe "a DELETE to :destroy" do
      describe "with a job owned by the admin" do
        setup do
          Job.any_instance.stubs(:started_by?).returns(true)

          delete :destroy, project_id: project.id, id: job
        end

        it "responds with 200" do
          response.status.must_equal(200)
        end
      end
      describe "with a valid job" do
        setup do
          delete :destroy, project_id: project.id, id: job
        end

        it "responds ok" do
          response.status.must_equal(200)
        end
      end
    end
  end
end
