require_relative '../../../test_helper'

SingleCov.covered!

describe Api::V1::DeploysController do
  it "routes" do
    assert_routing(
      { method: "post", path: "/api/v1/deploys" },
      controller: "api/v1/deploys", action: "create", format: "json"
    )
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
  let(:reference_service) { stub(find_git_references: git_references) }
  let(:git_references) { ["master"] }
  let(:token) { user.token }

  let(:params) do
    {
      project_id: project.to_param,
      stage_id: stage.to_param,
      deploy: {
        reference: "master",
      }
    }
  end

  as_a_project_deployer do
    before do
      DeployService.stubs(:new).with(user).returns(deploy_service)
      deploy_service.stubs(:deploy!).capture(deploy_called).returns(deploy)

      Deploy.any_instance.stubs(:changeset).returns(changeset)

      Project.stubs(:find_by_param!).with(project.to_param).returns(project)

      ReferencesService.stubs(:new).with(project).returns(reference_service)
    end

    describe "a POST to :create" do
      let(:params) { { deploy: { reference: "master" }} }

      before do
        post :create, params.merge(project_id: project.to_param, stage_id: stage.to_param, format: format)
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

        describe "with an invalid git reference" do
          let(:git_references) { [] }

          it "responds with unprocessable entity" do
            assert_response :unprocessable_entity
          end
        end
      end
    end
  end
end
