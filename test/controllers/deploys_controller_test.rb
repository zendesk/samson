require_relative '../test_helper'

SingleCov.covered!

describe DeploysController do
  def self.with_and_without_project(&block)
    [true, false].each do |scoped_to_project|
      describe "#{"not " unless scoped_to_project} scoped to project" do
        let(:project_id) { scoped_to_project ? project.to_param : nil }

        instance_eval(&block)
      end
    end
  end

  let(:project) { job.project }
  let(:stage) { stages(:test_staging) }
  let(:admin) { users(:admin) }
  let(:command) { job.command }
  let(:job) { jobs(:succeeded_test) }
  let(:deploy) { deploys(:succeeded_test) }
  let(:deploy_service) { stub(deploy!: nil, stop!: nil) }
  let(:deploy_called) { [] }
  let(:changeset) { stub_everything(commits: [], files: [], pull_requests: [], jira_issues: []) }

  it "routes" do
    assert_routing(
      "/projects/1/stages/2/deploys/new",
      controller: "deploys", action: "new", project_id: "1", stage_id: "2"
    )
    assert_routing({ method: "post", path: "/projects/1/stages/2/deploys" },
      controller: "deploys", action: "create", project_id: "1", stage_id: "2")
  end

  as_a_viewer do
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

      it "renders without a project" do
        get :index
        assert_template :index
        assigns[:deploys].must_equal Deploy.all.to_a
      end

      it "renders with given ids" do
        get :index, ids: [deploy.id]
        assert_template :index
        assigns[:deploys].must_equal [deploy]
      end

      it "fails when given ids do not exist" do
        assert_raises ActiveRecord::RecordNotFound do
          get :index, ids: [121211221]
        end
      end
    end

    describe "a GET to :active" do
      with_and_without_project do
        it "renders the template" do
          get :active, project_id: project_id
          assert_template :active
        end

        it "renders the partial" do
          get :active, project_id: project_id, partial: true
          assert_template 'shared/_deploys_table'
        end
      end
    end

    describe "a GET to :active_count" do
      before do
        stage.create_deploy(admin, reference: 'reference')
        get :active_count
      end

      it "renders json" do
        assert_equal "application/json", @response.content_type
        assert_response :ok
        @response.body.must_equal "1"
      end
    end

    describe "a GET to :changeset" do
      before do
        get :changeset, id: deploy.id, project_id: project.to_param
      end

      it "renders" do
        assert_template :changeset
      end

      it "does not render when the latest changeset is already cached in the browser" do
        request.env["HTTP_IF_NONE_MATCH"] = response.headers["ETag"]
        request.env["HTTP_IF_MODIFIED_SINCE"] = 2.minutes.ago.rfc2822

        get :changeset, id: deploy.id, project_id: project.to_param

        assert_response :not_modified
      end
    end

    describe "a GET to :show" do
      describe "with a valid deploy" do
        before { get :show, project_id: project.to_param, id: deploy.to_param }

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
        before { get :show, format: :text, project_id: project.to_param, id: deploy.to_param }

        it "responds with a plain text file" do
          assert_equal response.content_type, "text/plain"
        end

        it "responds with a .log file" do
          assert response.header["Content-Disposition"] =~ /\.log"$/
        end
      end
    end

    describe "a GET to :search" do
      before do
        Deploy.delete_all
        Job.delete_all
        cmd = 'cap staging deploy'
        project = Project.first
        job_def = {project_id: project.id, command: cmd, status: nil, user_id: admin.id}
        status = [
          {status: 'failed', production: true },
          {status: 'running', production: true},
          {status: 'succeeded', production: true},
          {status: 'succeeded', production: false}
        ]

        status.each do |stat|
          job_def[:status] = stat[:status]
          job = Job.create!(job_def)
          Deploy.create!(
            stage_id: Stage.find_by_production(stat[:production]).id,
            reference: 'reference',
            job_id: job.id
          )
        end
      end

      it "it renders json" do
        get :search, format: "json"
        assert_response :ok
      end

      it "renders html" do
        get :search, format: "html"
        assert_equal "text/html", @response.content_type
        assert_response :ok
      end

      it "returns no results when deploy is not found" do
        get :search, format: "json", deployer: 'jimmyjoebob'
        assert_response :ok
        @response.body.must_equal "{\"deploys\":\[\]}"
      end

      it "fitlers results by deployer" do
        get :search, format: "json", deployer: 'Admin'
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 4
      end

      it "filters results by status" do
        get :search, format: "json", status: 'succeeded'
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 2
      end

      it "ignores empty status" do
        get :search, format: "json", status: ' '
        assert_response 200
      end

      it "fails with invalid status" do
        get :search, format: "json", status: 'bogus_status'
        assert_response 400
      end

      it "filters by project" do
        get :search, format: "json", project_name: "Project"
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 4
      end

      it "filters by non-production" do
        get :search, format: "json", production: 0
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 1
      end

      it "filters by non-production" do
        get :search, format: "json", production: "false"
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 1
      end

      it "filters by production" do
        get :search, format: "json", production: 1
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 3
      end

      it "filters by production" do
        get :search, format: "json", production: "true"
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 3
      end
    end

    unauthorized :get, :new, project_id: :foo, stage_id: 2
    unauthorized :post, :create, project_id: :foo, stage_id: 2
    unauthorized :post, :buddy_check, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_project_deployer do
    before do
      DeployService.stubs(:new).with(user).returns(deploy_service)
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
      let(:params) { { deploy: { reference: "master" }} }

      before do
        post :create, params.merge(project_id: project.to_param, stage_id: stage.to_param, format: format)
      end

      describe "as html" do
        let(:format) { :html }

        it "redirects to the job path" do
          assert_redirected_to project_deploy_path(project, deploy)
        end

        it "creates a deploy" do
          assert_equal [[stage, {"reference" => "master"}]], deploy_called
        end

        describe "when invalid" do
          let(:deploy) { Deploy.new } # save failed

          it "renders deploy form" do
            assert_template :new
          end
        end
      end

      describe "as json" do
        let(:format) { :json }

        it "responds created" do
          assert_response :created
        end

        it "creates a deploy" do
          assert_equal [[stage, {"reference" => "master"}]], deploy_called
        end

        describe "when invalid" do
          let(:deploy) { Deploy.new } # save failed

          it "responds with an error" do
            assert_response :unprocessable_entity
          end
        end
      end
    end

    describe "a POST to :confirm" do
      before do
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
        deploy.reload.buddy.must_equal user
      end
    end

    describe "a DELETE to :destroy" do
      describe "with a deploy owned by the user" do
        before do
          DeployService.stubs(:new).with(user).returns(deploy_service)
          Job.any_instance.stubs(:started_by?).returns(true)
          deploy_service.expects(:stop!).once

          delete :destroy, project_id: project.to_param, id: deploy.to_param
        end

        it "cancels a deploy" do
          flash[:error].must_be_nil
        end
      end

      describe "with a deploy not owned by the user" do
        before do
          deploy_service.expects(:stop!).never
          Deploy.any_instance.stubs(:started_by?).returns(false)
          User.any_instance.stubs(:admin?).returns(false)

          delete :destroy, project_id: project.to_param, id: deploy.to_param
        end

        it "doesn't cancel the deloy" do
          flash[:error].wont_be_nil
        end
      end
    end
  end

  as_a_project_admin do
    before do
      DeployService.stubs(:new).with(user).returns(deploy_service)
    end

    describe "a DELETE to :destroy" do
      it "cancels the deploy" do
        deploy_service.expects(:stop!).once
        delete :destroy, project_id: project.to_param, id: deploy.to_param
        flash[:error].must_be_nil
      end
    end
  end
end
