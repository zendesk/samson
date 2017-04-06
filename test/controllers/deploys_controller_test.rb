# frozen_string_literal: true
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
    describe "#index" do
      before do
        Deploy.any_instance.stubs(:changeset).returns(changeset)
      end

      it "renders html" do
        get :index, params: {project_id: project}
        assert_template :index
      end

      it "renders without a project" do
        get :index
        assert_template :index
        assigns[:deploys].must_equal Deploy.all.to_a
      end

      it "renders with given ids" do
        get :index, params: {ids: [deploy.id]}
        assert_template :index
        assigns[:deploys].must_equal [deploy]
      end

      it "fails when given ids do not exist" do
        assert_raises ActiveRecord::RecordNotFound do
          get :index, params: {ids: [121211221]}
        end
      end
    end

    describe "#active" do
      with_and_without_project do
        it "renders the template" do
          get :active, params: {project_id: project_id}
          assert_template :active
        end

        it "renders the partial" do
          get :active, params: {project_id: project_id, partial: true}
          assert_template 'shared/_deploys_table'
        end
      end

      it "renders debug output with job/deploy and active/queued" do
        JobExecution.any_instance.expects(:on_complete).times(4)
        JobExecution.any_instance.expects(:start!)
        with_job_execution do
          # start 1 job and queue another
          active = Job.new(project: project) { |j| j.id = 123321 }
          active.stubs(:deploy).returns(deploy)
          queued = Job.new(project: project) { |j| j.id = 234432 }
          JobExecution.start_job(JobExecution.new('master', active), queue: :x)
          JobExecution.start_job(JobExecution.new('master', queued), queue: :x)
          JobExecution.active.size.must_equal 1
          assert JobExecution.queued?(queued.id)

          get :active, params: {debug: '1'}

          response.body.wont_include active.id.to_s
          response.body.must_include active.deploy.id.to_s # renders as deploy
          response.body.must_include queued.id.to_s # renders as job
        end
      end
    end

    describe "#changeset" do
      before do
        get :changeset, params: {id: deploy.id, project_id: project.to_param}
      end

      it "renders" do
        assert_template :changeset
      end

      it "does not render when the latest changeset is already cached in the browser" do
        request.env["HTTP_IF_NONE_MATCH"] = response.headers["ETag"]
        request.env["HTTP_IF_MODIFIED_SINCE"] = 2.minutes.ago.rfc2822

        get :changeset, params: {id: deploy.id, project_id: project.to_param}

        assert_response :not_modified
      end
    end

    describe "#show" do
      describe "with a valid deploy" do
        before { get :show, params: {project_id: project.to_param, id: deploy.to_param } }

        it "renders the template" do
          assert_template :show
        end
      end

      it "fails with unknown deploy" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: project.to_param, id: "deploy:nope"}
        end
      end

      describe "with format .text" do
        before { get :show, params: {format: :text, project_id: project.to_param, id: deploy.to_param } }

        it "responds with a plain text file" do
          assert_equal response.content_type, "text/plain"
        end

        it "responds with a .log file" do
          assert response.header["Content-Disposition"] =~ /\.log"$/
        end
      end
    end

    describe "#search" do
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
            project: project,
            job_id: job.id
          )
        end
      end

      it "renders json" do
        get :search, params: {format: "json"}
        assert_response :ok
      end

      it "renders csv" do
        get :search, params: {format: "csv"}
        assert_response :ok
        @response.body.split("\n").length.must_equal 7 # 4 records and 3 meta rows
      end

      it "renders csv with limit (1) records and links to generate full report" do
        get :search, params: {format: "csv", limit: 1}
        assert_response :ok
        @response.body.split("\n").length.must_equal 6 # 1 record and 5 meta rows
        @response.body.split("\n")[2].split(",")[2].to_i.must_equal(1) # validate that count equals = csv_limit
      end

      it "renders html" do
        get :search, params: {format: "html"}
        assert_equal "text/html", @response.content_type
        assert_response :ok
      end

      it "returns no results when deploy is not found" do
        get :search, params: {format: "json", deployer: 'jimmyjoebob'}
        assert_response :ok
        @response.body.must_equal "{\"deploys\":\[\]}"
      end

      it "fitlers results by deployer" do
        get :search, params: {format: "json", deployer: 'Admin'}
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 4
      end

      it "filters results by status" do
        get :search, params: {format: "json", status: 'succeeded'}
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 2
      end

      it "ignores empty status" do
        get :search, params: {format: "json", status: ' '}
        assert_response 200
      end

      it "fails with invalid status" do
        get :search, params: {format: "json", status: 'bogus_status'}
        assert_response 400
      end

      it "filters by project" do
        get :search, params: {format: "json", project_name: "Foo"}
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 4
      end

      it "filters by non-production" do
        get :search, params: {format: "json", production: 0}
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 1
      end

      it "filters by non-production" do
        get :search, params: {format: "json", production: "false"}
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 1
      end

      it "filters by production" do
        get :search, params: {format: "json", production: 1}
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 3
      end

      it "filters by production" do
        get :search, params: {format: "json", production: "true"}
        assert_response :ok
        deploys = JSON.parse(@response.body)
        deploys["deploys"].count.must_equal 3
      end
    end

    unauthorized :get, :new, project_id: :foo, stage_id: 2
    unauthorized :post, :create, project_id: :foo, stage_id: 2
    unauthorized :post, :buddy_check, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
    unauthorized :post, :confirm, project_id: :foo, stage_id: 2
  end

  as_a_project_deployer do
    before do
      DeployService.stubs(:new).with(user).returns(deploy_service)
      deploy_service.stubs(:deploy!).capture(deploy_called).returns(deploy)

      Deploy.any_instance.stubs(:changeset).returns(changeset)
    end

    describe "#new" do
      it "sets stage and reference" do
        get :new, params: {project_id: project.to_param, stage_id: stage.to_param, reference: "abcd"}
        deploy = assigns(:deploy)
        deploy.reference.must_equal "abcd"
      end
    end

    describe "#create" do
      let(:params) { { deploy: { reference: "master" }} }

      before do
        post :create, params: params.merge(project_id: project.to_param, stage_id: stage.to_param, format: format)
      end

      describe "as html" do
        let(:format) { :html }

        it "redirects to the job path" do
          assert_redirected_to project_deploy_path(project, deploy)
        end

        it "creates a deploy" do
          deploy_called.each { |c| c[1] = c[1].to_h }
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
          deploy_called.each { |c| c[1] = c[1].to_h }
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

    describe "#confirm" do
      before do
        Deploy.delete_all # triggers more callbacks

        post :confirm, params: {project_id: project.to_param, stage_id: stage.to_param, deploy: { reference: "master" }}
      end

      it "renders the template" do
        assert_template :changeset
      end
    end

    describe "#buddy_check" do
      let(:deploy) { deploys(:succeeded_test) }
      before { deploy.job.update_column(:status, 'pending') }

      it "confirms and redirects to the deploy" do
        DeployService.stubs(:new).with(deploy.user).returns(deploy_service)
        deploy_service.expects(:confirm_deploy!)
        refute deploy.buddy

        post :buddy_check, params: {project_id: project.to_param, id: deploy.id}

        assert_redirected_to project_deploy_path(project, deploy)
        deploy.reload.buddy.must_equal user
      end
    end

    describe "#destroy" do
      describe "with a deploy owned by the user" do
        before do
          DeployService.stubs(:new).with(user).returns(deploy_service)
          Job.any_instance.stubs(:started_by?).returns(true)
          Deploy.any_instance.expects(:stop!).once

          delete :destroy, params: {project_id: project.to_param, id: deploy.to_param}
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

          delete :destroy, params: {project_id: project.to_param, id: deploy.to_param}
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

    describe "#destroy" do
      it "cancels the deploy" do
        Deploy.any_instance.expects(:stop!).once
        delete :destroy, params: {project_id: project.to_param, id: deploy.to_param}
        flash[:error].must_be_nil
      end
    end
  end
end
