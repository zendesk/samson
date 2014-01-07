require 'test_helper'

describe DeploysController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:admin) { users(:admin) }
  let(:command) { "echo hello" }
  let(:job) { Job.create!(command: command, project: project, user: admin) }
  let(:deploy) { Deploy.create!(stage: stage, job: job, commit: "foo") }
  let(:deploy_service) { stub(deploy!: nil) }

  setup do
    DeployService.stubs(:new).with(project, stage, admin).returns(deploy_service)
    deploy_service.stubs(:deploy!).returns(deploy)
  end

  as_a_viewer do
    describe "a GET to :index" do
      setup { get :index, project_id: project.id }

      it "renders the template" do
        assert_template :index
      end
    end

    describe "a GET to :active" do
      setup { get :active, project_id: project.id }

      it "renders the template" do
        assert_template :index
      end
    end

    describe "a GET to :show" do
      describe "with a valid deploy" do
        setup { get :show, project_id: project.id, id: deploy.to_param }

        it "renders the template" do
          assert_template :show
        end
      end

      describe "with no deploy" do
        setup { get :show, project_id: project.id, id: "deploy:nope" }

        it "redirects to the root page" do
          assert_redirected_to root_path
        end

        it "sets the flash error" do
          request.flash[:error].wont_be_nil
        end
      end
    end

    describe "a POST to :create" do
      setup { post :create, project_id: project.id }
      it_is_unauthorized
    end

    describe "a DELETE to :destroy" do
      setup do
        deploy.stubs(:stop!)
        delete :destroy, project_id: project.id, id: job.to_param
      end

      it_is_unauthorized
    end
  end

  as_a_admin do
    describe "a POST to :create" do
      setup do
        post :create, params.merge(project_id: project.id)
      end

      let(:params) {{ deploy: {
        stage_id: stage.id,
        commit: "master"
      }}}

      it "redirects to the job path" do
        assert_redirected_to project_deploy_path(project, deploy)
      end

      it "creates a deploy" do
        assert_received(deploy_service, :deploy!) do |expect|
          expect.with "master"
        end
      end
    end

    describe "a DELETE to :destroy" do
      describe "with a valid deploy" do
        setup do
          delete :destroy, project_id: project.id, id: deploy.to_param
        end

        it "responds ok" do
          response.status.must_equal(200)
        end
      end

      as_a_deployer do
        setup do
          delete :destroy, project_id: project.id, id: deploy.to_param
        end

        it "is forbidden" do
          response.status.must_equal(403)
        end
      end
    end
  end
end
