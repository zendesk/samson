require_relative '../test_helper'

describe DeploysController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:deployer) { users(:deployer) }
  let(:command) { "echo hello" }
  let(:job) { Job.create!(command: command, project: project, user: deployer) }
  let(:deploy) { Deploy.create!(stage: stage, job: job, reference: "foo") }
  let(:deploy_service) { stub(deploy!: nil) }

  setup do
    DeployService.stubs(:new).with(project, deployer).returns(deploy_service)
    deploy_service.stubs(:deploy!).returns(deploy)
  end

  as_a_viewer do
    describe "a GET to :index" do
      setup { get :index, project_id: project.id, format: format }

      describe "as html" do
        let(:format) { :html }

        it "renders the template" do
          assert_template :index
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
      setup { get :recent, project_id: project.id, format: format }

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
          assert_template :active
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
      setup { get :active, project_id: project.id, format: format }

      describe "as html" do
        let(:format) { :html }

        it "renders the template" do
          assert_template :active
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

    describe "a GET to :show" do
      setup do
        changeset = stub_everything(files: [], commits: [], pull_requests: [], jira_issues: [])
        Changeset.stubs(:find).returns(changeset)
      end

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

      describe "with format .text" do
        setup { get :show, format: :text, project_id: project.id, id: deploy.to_param }

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
    describe "a POST to :create" do
      setup do
        post :create, params.merge(project_id: project.id, format: format)
      end

      let(:params) {{ deploy: {
        stage_id: stage.id,
        reference: "master"
      }}}

      describe "as html" do
        let(:format) { :html }

        it "redirects to the job path" do
          assert_redirected_to project_deploy_path(project, deploy)
        end

        it "creates a deploy" do
          assert_received(deploy_service, :deploy!) do |expect|
            expect.with stage, "master"
          end
        end
      end

      describe "as json" do
        let(:format) { :json }

        it "responds ok" do
          assert_response :ok
        end

        it "creates a deploy" do
          assert_received(deploy_service, :deploy!) do |expect|
            expect.with stage, "master"
          end
        end
      end
    end

    describe "a POST to :confirm" do
      let(:changeset) { stub_everything(commits: [], files: [], pull_requests: [], jira_issues: []) }

      setup do
        Changeset.stubs(:find).with(project.github_repo, nil, 'master').returns(changeset)

        post :confirm, project_id: project.id, deploy: {
          stage_id: stage.id,
          reference: "master",
        }
      end

      it "renders the template" do
        assert_template :changeset
      end
    end

    describe "a DELETE to :destroy" do
      describe "with a deploy owned by the deployer" do
        setup do
          Deploy.any_instance.stubs(:started_by?).returns(true)

          delete :destroy, project_id: project.id, id: deploy.to_param
        end

        it "responds with 200" do
          response.status.must_equal(200)
        end
      end

      describe "with a deploy not owned by the deployer" do
        setup do
          Deploy.any_instance.stubs(:started_by?).returns(false)
          User.any_instance.stubs(:is_admin?).returns(false)

          delete :destroy, project_id: project.id, id: deploy.to_param
        end

        it "responds with 403" do
          response.status.must_equal(403)
        end
      end
    end

  end

  as_a_admin do
    describe "a DELETE to :destroy" do
      describe "with a valid deploy" do
        setup do
          delete :destroy, project_id: project.id, id: deploy.to_param
        end

        it "responds ok" do
          response.status.must_equal(200)
        end
      end
    end
  end
end
