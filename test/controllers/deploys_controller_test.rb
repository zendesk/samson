# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 1

describe DeploysController do
  def self.with_and_without_project(&block)
    [true, false].each do |scoped_to_project|
      describe "#{"not " unless scoped_to_project} scoped to project" do
        let(:project_id) { scoped_to_project ? project.to_param : nil }

        instance_eval(&block)
      end
    end
  end

  def changeset(overrides = {})
    attrs = {commits: [], files: [], pull_requests: [], jira_issues: []}.merge(overrides)
    stub_everything('Changeset', attrs)
  end

  let(:project) { job.project }
  let(:stage) { stages(:test_staging) }
  let(:admin) { users(:admin) }
  let(:command) { job.command }
  let(:job) { jobs(:succeeded_test) }
  let(:deploy) { deploys(:succeeded_test) }
  let(:deploy_service) { stub(deploy: nil, cancel: nil) }
  let(:deploy_called) { [] }
  let(:json) { JSON.parse(@response.body) }

  it "routes" do
    assert_routing(
      "/projects/1/stages/2/deploys/new",
      controller: "deploys", action: "new", project_id: "1", stage_id: "2"
    )
    assert_routing(
      {method: "post", path: "/projects/1/stages/2/deploys"},
      controller: "deploys", action: "create", project_id: "1", stage_id: "2"
    )
  end

  as_a :viewer do
    describe "#active" do
      with_and_without_project do
        it "renders the template" do
          get :active, params: {project_id: project_id}
          assert_template :active
        end

        it "renders the partial" do
          get :active, params: {project_id: project_id, partial: true}
          assert_template 'deploys/_table'
        end
      end

      it "renders debug output with job/deploy and executing/queued" do
        with_blocked_jobs 2 do
          # start 1 job and keep it executing
          executing = Job.create!(project: project, command: "echo 1", user: user) { |j| j.id = 11111 }
          executing.stubs(:deploy).returns(deploy)
          JobQueue.perform_later(JobExecution.new('master', executing), queue: :x)

          # queue 1 job after it
          queued = Job.create!(project: project, command: "echo 1", user: user) { |j| j.id = 22222 }
          JobQueue.perform_later(JobExecution.new('master', queued), queue: :x)

          assert JobQueue.executing?(executing.id)
          assert JobQueue.queued?(queued.id)

          get :active, params: {debug: '1'}

          response.body.wont_include executing.id.to_s
          response.body.must_include executing.deploy.id.to_s # renders as deploy
          response.body.must_include queued.id.to_s # renders as job
        end
      end

      it 'renders active deploy expected time' do
        Deploy.expects(:active).twice.returns([deploy])
        deploy.expects(:active?).returns(true)
        deploy.stage.expects(:average_deploy_time).returns(4.123)

        get :active

        response.body.must_include "(00:00:04)"
      end
    end

    describe '#active_count' do
      it "renders" do
        jobs(:succeeded_test).update_column :status, 'running'
        get :active_count, format: :json
        response.body.must_equal "1"
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
      it "renders" do
        get :show, params: {project_id: project, id: deploy}
        assert_template :show
      end

      it "renders soft deleted" do
        deploy.soft_delete!
        get :show, params: {project_id: project, id: deploy, with_deleted: "Project,Stage,Deploy"}
        assert_template :show
      end

      it "fails on missing params" do
        deploy.soft_delete!
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: project, id: deploy}
        end
      end

      it "fails with unknown deploy" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: project.to_param, id: "deploy:nope"}
        end
      end

      describe "with format .text" do
        before { get :show, params: {format: :text, project_id: project.to_param, id: deploy.to_param} }

        it "responds with a plain text file" do
          assert_equal response.media_type, "text/plain"
        end

        it "responds with a .log file" do
          assert response.header["Content-Disposition"] =~ /\.log"/
        end
      end

      describe "with format .json" do
        it "renders without project" do
          get :show, params: {format: :json, id: deploy.to_param}
          json.keys.must_equal ['deploy']
          json['deploy']['id'].must_equal deploy.id
        end

        it "renders with includes" do
          get :show, params: {format: :json, id: deploy.to_param, includes: 'project,stage'}
          json.keys.must_equal ['deploy', 'projects', 'stages']
        end
      end
    end

    describe "#index" do
      let(:deploy) { Deploy.first }
      let(:deploys) { JSON.parse(@response.body) }

      before do
        Deploy.delete_all
        Job.delete_all
        cmd = 'cap staging deploy'
        project = projects(:test)
        job_def = {project_id: project.id, command: cmd, status: nil, user_id: admin.id}
        statuses = [
          {status: 'failed', production: true},
          {status: 'running', production: true},
          {status: 'succeeded', production: true},
          {status: 'succeeded', production: false}
        ]

        statuses.each do |status|
          job_def[:status] = status[:status]
          job = Job.create!(job_def)
          Deploy.create!(
            stage: stages(status[:production] ? :test_production : :test_staging),
            reference: 'reference',
            project: project,
            job_id: job.id
          )
        end
      end

      it "renders json" do
        get :index, format: "json"
        assert_response :ok
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

      it "renders with soft_delete" do
        deploy.soft_delete!
        get :index, params: {with_deleted: "Project,Stage,Deploy"}
        assert_template :index
        assigns[:deploys].must_include deploy
      end

      it "skips deleted without params" do
        deploy.soft_delete!
        get :index
        assert_template :index
        assigns[:deploys].wont_include deploy
      end

      it "can scope by project" do
        Deploy.where.not(id: deploy.id).update_all(project_id: 123)
        get :index, params: {project_id: deploy.project}
        assert_template :index
        assigns[:deploys].must_equal [deploy]
      end

      it "renders csv" do
        get :index, format: "csv"
        assert_response :ok
        @response.body.split("\n").length.must_equal 7 # 4 records and 3 meta rows
      end

      it "renders csv with limit (1) records and links to generate full report" do
        get :index, params: {limit: 1}, format: "csv"
        assert_response :ok
        @response.body.split("\n").length.must_equal 6 # 1 record and 5 meta rows
        @response.body.split("\n")[2].split(",")[2].to_i.must_equal(1) # validate that count equals = csv_limit
      end

      it "renders html" do
        get :index
        assert_equal "text/html", @response.media_type
        assert_response :ok
      end

      it "returns no results when deploy is not found" do
        get :index, params: {search: {deployer: 'jimmyjoebob'}}, format: "json"
        assert_response :ok
        @response.body.must_equal "{\"deploys\":\[\]}"
      end

      it "fitlers results by deployer" do
        get :index, params: {search: {deployer: 'Admin'}}, format: "json"
        assert_response :ok
        deploys["deploys"].count.must_equal 4
      end

      it "filters results by status" do
        get :index, params: {search: {status: 'succeeded'}}, format: "json"
        assert_response :ok
        deploys["deploys"].count.must_equal 2
      end

      it "filters results by git_sha" do
        Job.last.update_column(:commit, "ababababab")
        get :index, params: {search: {git_sha: "ababababab"}}, format: "json"
        assert_response :ok
        deploys["deploys"].count.must_equal 1
      end

      it "ignores empty status" do
        get :index, params: {search: {status: ' '}}, format: "json"
        assert_response 200
      end

      it "fails with invalid status" do
        get :index, params: {search: {status: 'bogus_status'}}, format: "json"
        assert_response 400
      end

      it "filters by project" do
        get :index, params: {search: {project_name: "Foo"}}, format: "json"
        assert_response :ok
        deploys["deploys"].count.must_equal 4
      end

      it "filters by permalinks" do
        Deploy.last.update_column(:project_id, projects(:other).id)

        get :index, params: {search: {project_permalinks: 'foo,bar'}}, format: "json"
        deploys['deploys'].count.must_equal 4
      end

      it 'filters by project and permalink' do
        Deploy.last.update_column(:project_id, projects(:other).id)

        get :index, params: {search: {project_name: 'Foo', project_permalinks: 'foo'}}, format: "json"
        deploys['deploys'].count.must_equal 4
      end

      it "filters by non-production via json" do
        get :index, params: {search: {production: 0}}, format: "json"
        assert_response :ok
        json["deploys"].count.must_equal 1
      end

      it "filters by non-production" do
        get :index, params: {search: {production: "false"}}, format: "json"
        assert_response :ok
        deploys["deploys"].count.must_equal 1
      end

      it "filters by production via json" do
        get :index, params: {search: {production: 1}}, format: "json"
        assert_response :ok
        deploys["deploys"].count.must_equal 3
      end

      it "filters by production via json boolean" do
        get :index, params: {search: {production: false}}, format: "json"
        assert_response :ok
        deploys["deploys"].count.must_equal 1
      end

      it "filters by production" do
        get :index, params: {search: {production: "true"}}, format: "json"
        assert_response :ok
        deploys["deploys"].count.must_equal 3
      end

      it "filters for code_deployed" do
        Deploy.last.stage.update_column(:no_code_deployed, true)
        get :index, params: {search: {code_deployed: "true"}}, format: "json"
        assert_response :ok
        deploys["deploys"].count.must_equal 3
      end

      it "filters by group" do
        group = deploy_groups(:pod1)
        get :index, params: {search: {group: "DeployGroup-#{group.id}"}}, format: "json"
        assert_response :ok
        assigns[:deploys].map(&:stage).map(&:name).uniq.must_equal ["Production"]
      end

      it "filters by environment" do
        get :index, params: {search: {group: "Environment-#{environments(:production).id}"}}, format: "json"
        assert_response :ok
        assigns[:deploys].map(&:stage).map(&:name).uniq.must_equal ["Production"]
      end

      it "filters by updated_at (finished_at)" do
        t = Time.now - 1.day
        expected = Deploy.last(3)
        expected.each_with_index { |d, i| d.update_column :updated_at, (t + i).to_s(:db) }

        get :index, params: {search: {updated_at: [t.to_s(:db), (t + 2).to_s(:db)]}}, format: "json"

        assert_response :ok
        assigns[:deploys].map(&:id).sort.must_equal expected.map(&:id).sort
      end

      it "filters by deleted" do
        Deploy.last.soft_delete!
        get :index, params: {search: {deleted: "Project,Stage,Deploy"}}, format: "json"
        assert_response :ok
        deploys["deploys"].count.must_equal 1
      end

      it "fails when filtering for unknown" do
        e = assert_raises RuntimeError do
          get :index, params: {search: {group: "Blob-#{environments(:production).id}"}}, format: "json"
        end
        e.message.must_equal "Unsupported type Blob"
      end
    end

    unauthorized :get, :new, project_id: :foo, stage_id: 2
    unauthorized :post, :create, project_id: :foo, stage_id: 2
    unauthorized :post, :buddy_check, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
    unauthorized :post, :confirm, project_id: :foo, stage_id: 2
  end

  as_a :project_deployer do
    before do
      DeployService.stubs(:new).with(user).returns(deploy_service)
      deploy_service.stubs(:deploy).capture(deploy_called).returns(deploy)

      Deploy.any_instance.stubs(:changeset).returns(changeset)
    end

    describe "#new" do
      it "sets stage and reference" do
        get :new, params: {project_id: project.to_param, stage_id: stage.to_param, reference: "abcd"}
        deploy = assigns(:deploy)
        deploy.stage.must_equal stage
        deploy.reference.must_equal "abcd"
      end

      describe "with default reference" do
        before { stage.update_column(:default_reference, 'pandas4lyfe') }

        it "sets default reference" do
          get :new, params: {project_id: project.to_param, stage_id: stage.to_param}
          assigns(:deploy).reference.must_equal 'pandas4lyfe'
        end

        it "sets passed in reference over default reference" do
          get :new, params: {project_id: project.to_param, stage_id: stage.to_param, reference: "abcd"}
          assigns(:deploy).reference.must_equal "abcd"
        end
      end
    end

    describe "#create" do
      let(:params) { {deploy: {reference: "master"}} }

      before do
        post :create, params: params.merge(project_id: project.to_param, stage_id: stage.to_param, format: format)
      end

      describe "as html" do
        let(:format) { :html }

        it "redirects to the job path" do
          assert_redirected_to project_deploy_path(project, deploy)
        end

        it "creates a deploy" do
          deploy_called.each { |c| c[1] = c[1].to_h.except(:project) }
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
          deploy_called.each { |c| c[1] = c[1].to_h.except(:project) }
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
      def confirm
        post :confirm, params: {project_id: project.to_param, stage_id: stage.to_param, deploy: {reference: "master"}}
      end

      def pull_request_stub(data_overrides = {})
        risks = data_overrides.delete(:risks)

        attrs = {
          number: 1,
          title: 'Cool Stuff!',
          additions: 0,
          deletions: 0,
        }.merge(data_overrides)

        pr = Changeset::PullRequest.new('foo/bar', Sawyer::Resource.new(Sawyer::Agent.new(''), attrs))
        pr.stubs(:parse_risks).returns(risks)
        pr
      end

      before do
        Deploy.delete_all # triggers more callbacks
      end

      it "renders the template" do
        confirm
        assert_template :changeset
      end

      it 'shows risks' do
        pr = pull_request_stub(risks: 'The sky is falling!')
        Deploy.any_instance.stubs(:changeset).returns(changeset(pull_requests: [pr]))

        confirm

        assert_response :success

        assert_select 'h5' do
          assert_select 'strong', text: '#1'
          assert_select 'a[href=?]', 'https://github.com/foo/bar/pull/1', text: 'Cool Stuff!'
        end
        assert_select 'p', text: 'The sky is falling!'
      end

      it 'shows warning if risk is not found' do
        pr = pull_request_stub
        Deploy.any_instance.stubs(:changeset).returns(changeset(pull_requests: [pr]))

        confirm

        assert_response :success

        assert_select 'i[class=?]', 'glyphicon glyphicon-alert deployment-alert'
      end
    end

    describe "#buddy_check" do
      let(:deploy) { deploys(:succeeded_test) }
      before { deploy.job.update_column(:status, 'pending') }

      it "confirms and redirects to the deploy" do
        DeployService.stubs(:new).with(deploy.user).returns(deploy_service)
        deploy_service.expects(:confirm_deploy)
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
          Deploy.any_instance.expects(:cancel).once

          delete :destroy, params: {project_id: project.to_param, id: deploy.to_param}
        end

        it "redirects to project page" do
          assert_redirected_to "/projects/foo/deploys/#{deploy.id}"
        end
      end
    end
  end

  as_a :project_admin do
    before do
      DeployService.stubs(:new).with(user).returns(deploy_service)
    end

    describe "#destroy" do
      it "cancels the deploy" do
        Deploy.any_instance.expects(:cancel).once
        delete :destroy, params: {project_id: project.to_param, id: deploy.to_param}
        flash[:alert].must_be_nil
      end
    end
  end
end
