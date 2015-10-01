require_relative '../test_helper'

describe DeploysController do
  let(:project) { job.project }
  let(:stage) { deploy.stage }
  let(:admin) { users(:admin) }
  let(:command) { job.command }
  let(:job) { jobs(:succeeded_test) }
  let(:deploy) { deploys(:succeeded_test) }
  let(:deploy_service) { stub(deploy!: nil, stop!: nil) }
  let(:deploy_called) { [] }
  let(:changeset) { stub_everything(commits: [], files: [], pull_requests: [], jira_issues: []) }

  it "routes" do
    assert_routing "/projects/1/stages/2/deploys/new", controller: "deploys", action: "new", project_id: "1", stage_id: "2"
    assert_routing({ method: "post", path: "/projects/1/stages/2/deploys" },
      controller: "deploys", action: "create", project_id: "1", stage_id: "2")
  end

  as_a_viewer do
    let(:deployer) { users(:viewer) }

    describe "a GET to :index" do
      it "renders html" do
        get :index, project_id: project
        assert_template :index
      end

      it "renders json" do
        get :index, project_id: project, format: "json"
        assert_response :ok
        assert_equal "application/json", @response.content_type
      end
    end

    describe "a GET to :recent" do
      setup { get :recent, format: format }

      describe "as html" do
        let(:format) { :html }

        it "renders the template" do
          assert_template :recent
        end
      end

      describe "as json" do
        let(:format) { :json }

        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response :ok
        end
      end
    end

    describe "a GET to :recent with a project_id" do
      setup { get :recent, project_id: project.to_param, format: format }

      describe "as html" do
        let(:format) { :html }

        it "renders the template" do
          assert_template :recent
        end
      end

      describe "as json" do
        let(:format) { :json }

        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response :ok
        end
      end
    end

    describe "a GET to :active" do
      setup { get :active, format: format }

      describe "as html" do
        let(:format) { :html }

        it "renders the template" do
          assert_template :recent
        end
      end

      describe "as json" do
        let(:format) { :json }

        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response :ok
        end
      end
    end

    describe "a GET to :active with a project_id" do
      setup { get :active, project_id: project.to_param, format: format }

      describe "as html" do
        let(:format) { :html }

        it "renders the template" do
          assert_template :recent
        end
      end

      describe "as json" do
        let(:format) { :json }

        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response :ok
        end
      end
    end

    describe "#active_count" do
      before { stage.create_deploy(admin, { reference: 'reference' }) }

      it "renders json" do
        get :active_count
        assert_equal "application/json", @response.content_type
        assert_response :ok
        @response.body.must_equal "{\"deploy_count\":1}"
      end

      it "renders json" do
        get :active_count, project_id: project.to_param
        assert_equal "application/json", @response.content_type
        assert_response :ok
        @response.body.must_equal "{\"deploy_count\":1}"
      end
    end

    describe "a GET to :show" do
      describe "with a valid deploy" do
        setup { get :show, project_id: project.to_param, id: deploy.to_param }

        it "renders the template" do
          assert_template :show
        end
      end

      it "fails with unknown deploy" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, project_id: project.to_param, id: "deploy:nope"
        end
      end

      describe "with format .text" do
        setup { get :show, format: :text, project_id: project.to_param, id: deploy.to_param }

        it "responds with a plain text file" do
          assert_equal response.content_type, "text/plain"
        end

        it "responds with a .log file" do
          assert response.header["Content-Disposition"] =~ /\.log"$/
        end
      end
    end

    unauthorized :get, :new, project_id: :foo, stage_id: 2
    unauthorized :post, :create, project_id: :foo, stage_id: 2
    unauthorized :post, :buddy_check, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_deployer do
    let(:deployer) { users(:deployer) }

    setup do
      DeployService.stubs(:new).with(deployer).returns(deploy_service)
      deploy_service.stubs(:deploy!).capture(deploy_called).returns(deploy)

      Deploy.any_instance.stubs(:changeset).returns(changeset)
    end

    describe "a GET to :new" do
      it "sets stage and reference" do
        get :new, project_id: project.to_param, stage_id: stage.to_param, reference: "abcd"
        deploy = assigns(:deploy)
        deploy.reference.must_equal "abcd"
      end
    end

    describe "a POST to :create" do

      setup do
        post :create, params.merge(project_id: project.to_param, stage_id: stage.to_param, format: format)
      end

      let(:params) {{ deploy: { reference: "master" }}}

      describe "as html" do
        let(:format) { :html }

        it "redirects to the job path" do
          assert_redirected_to project_deploy_path(project, deploy)
        end

        it "creates a deploy" do
          assert_equal [[stage, {"reference" => "master"}]], deploy_called
        end
      end

      describe "as json" do
        let(:format) { :json }

        it "responds ok" do
          assert_response :ok
        end

        it "creates a deploy" do
          assert_equal [[stage, {"reference" => "master"}]], deploy_called
        end
      end
    end

    describe "a POST to :confirm" do
      setup do
        Deploy.delete_all # triggers more callbacks

        post :confirm, project_id: project.to_param, stage_id: stage.to_param, deploy: { reference: "master" }
      end

      it "renders the template" do
        assert_template :changeset
      end
    end

    describe "a POST to :buddy_check" do
      let(:deploy) { deploys(:succeeded_test) }
      before { deploy.job.update_column(:status, 'pending') }

      it "confirms and redirects to the deploy" do
        DeployService.stubs(:new).with(deploy.user).returns(deploy_service)
        deploy_service.expects(:confirm_deploy!)
        refute deploy.buddy

        post :buddy_check, project_id: project.to_param, id: deploy.id

        assert_redirected_to project_deploy_path(project, deploy)
        deploy.reload.buddy.must_equal deployer
      end
    end

    describe "a DELETE to :destroy" do
      describe "with a deploy owned by the deployer" do
        setup do
          DeployService.stubs(:new).with(deployer).returns(deploy_service)
          Job.any_instance.stubs(:started_by?).returns(true)
          deploy_service.expects(:stop!).once

          delete :destroy, project_id: project.to_param, id: deploy.to_param
        end

        it "cancels a deploy" do
          flash[:error].must_be_nil
        end
      end

      describe "with a deploy not owned by the deployer" do
        setup do
          deploy_service.expects(:stop!).never
          Deploy.any_instance.stubs(:started_by?).returns(false)
          User.any_instance.stubs(:is_admin?).returns(false)

          delete :destroy, project_id: project.to_param, id: deploy.to_param
        end

        it "doesn't cancel the deloy" do
          flash[:error].wont_be_nil
        end
      end
    end
  end

  as_a_admin do
    let(:deployer) { users(:admin) }

    setup do
      DeployService.stubs(:new).with(deployer).returns(deploy_service)
    end

    describe "a DELETE to :destroy" do
      describe "with a valid deploy" do
        setup do
          deploy_service.expects(:stop!).once
          delete :destroy, project_id: project.to_param, id: deploy.to_param
        end

        it "cancels the deploy" do
          flash[:error].must_be_nil
        end
      end
    end
  end

  as_a_viewer_project_deployer do
    let(:deployer) { users(:viewer_project_deployer) }

    setup do
      DeployService.stubs(:new).with(deployer).returns(deploy_service)
      deploy_service.stubs(:deploy!).capture(deploy_called).returns(deploy)

      Deploy.any_instance.stubs(:changeset).returns(changeset)
    end

    describe "a GET to :new" do
      it "sets stage and reference" do
        get :new, project_id: project.to_param, stage_id: stage.to_param, reference: "abcd"
        deploy = assigns(:deploy)
        deploy.reference.must_equal "abcd"
      end
    end

    describe "a POST to :create" do
      setup do
        post :create, params.merge(project_id: project.to_param, stage_id: stage.to_param, format: format)
      end

      let(:params) {{ deploy: { reference: "master" }}}

      describe "as html" do
        let(:format) { :html }

        it "redirects to the job path" do
          assert_redirected_to project_deploy_path(project, deploy)
        end

        it "creates a deploy" do
          assert_equal [[stage, {"reference" => "master"}]], deploy_called
        end
      end

      describe "as json" do
        let(:format) { :json }

        it "responds ok" do
          assert_response :ok
        end

        it "creates a deploy" do
          assert_equal [[stage, {"reference" => "master"}]], deploy_called
        end
      end
    end

    describe "a POST to :confirm" do
      setup do
        Deploy.delete_all # triggers more callbacks

        post :confirm, project_id: project.to_param, stage_id: stage.to_param, deploy: { reference: "master" }
      end

      it "renders the template" do
        assert_template :changeset
      end
    end

    describe "a POST to :buddy_check" do
      let(:deploy) { deploys(:succeeded_test) }
      before { deploy.job.update_column(:status, 'pending') }

      it "confirms and redirects to the deploy" do
        DeployService.stubs(:new).with(deploy.user).returns(deploy_service)
        deploy_service.expects(:confirm_deploy!)
        refute deploy.buddy

        post :buddy_check, project_id: project.to_param, id: deploy.id

        assert_redirected_to project_deploy_path(project, deploy)
        deploy.reload.buddy.must_equal deployer
      end
    end

    describe "a DELETE to :destroy" do
      describe "with a deploy owned by the deployer" do
        setup do
          DeployService.stubs(:new).with(deployer).returns(deploy_service)
          Job.any_instance.stubs(:started_by?).returns(true)
          deploy_service.expects(:stop!).once

          delete :destroy, project_id: project.to_param, id: deploy.to_param
        end

        it "cancels a deploy" do
          flash[:error].must_be_nil
        end
      end

      describe "with a deploy not owned by the deployer" do
        setup do
          deploy_service.expects(:stop!).never
          Deploy.any_instance.stubs(:started_by?).returns(false)
          User.any_instance.stubs(:is_admin?).returns(false)

          delete :destroy, project_id: project.to_param, id: deploy.to_param
        end

        it "doesn't cancel the deloy" do
          flash[:error].wont_be_nil
        end
      end
    end
  end
end
