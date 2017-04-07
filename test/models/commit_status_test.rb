# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe CommitStatus do
  def self.deploying_a_previous_release
    let(:reference) { 'v4.2' }
    let(:deploy) { deploys(:succeeded_production_test) }

    before do
      DeployGroup.stubs(enabled?: true)
      stage.deploy_groups << deploy_groups(:pod1)
      deploy.update_column(:reference, 'v4.3')
    end
  end

  def success!
    stub_github_api(url, statuses: [{foo: "bar"}], state: "success")
  end

  def failure!
    stub_github_api(url, nil, 404)
  end

  let(:stage) { stages(:test_staging) }
  let(:reference) { 'master' }
  let(:url) { "repos/#{stage.project.user_repo_part}/commits/#{reference}/status" }
  let(:status) { CommitStatus.new(stage, reference) }

  describe "#status" do
    it "returns state" do
      success!
      status.status.must_equal 'success'
    end

    it "is failure when not found" do
      failure!
      status.status.must_equal 'failure'
    end

    describe "when deploying a previous release" do
      deploying_a_previous_release

      it "warns" do
        success!
        assert_sql_queries 7 do
          status.status.must_equal 'error'
        end
      end

      it "warns when an older deploy has a lower version (grouping + ordering test)" do
        deploys(:succeeded_test).update_column(:stage_id, deploy.stage_id) # need 2 successful deploys on the same stage
        deploys(:succeeded_test).update_column(:reference, 'v4.1') # old is lower
        deploy.update_column(:reference, 'v4.3') # new is higher
        success!
        status.status.must_equal 'error'
      end

      it "ignores when previous deploy was the same or lower" do
        deploy.update_column(:reference, reference)
        success!
        status.status.must_equal 'success'
      end

      describe "when previous deploy was higher numerically" do
        before { deploy.update_column(:reference, 'v4.10') }

        it "warns" do
          success!
          status.status.must_equal 'error'
          status.status_list[1][:description].must_equal(
            "v4.10 was deployed to deploy groups in this stage by Production"
          )
        end

        it "warns with multiple higher deploys" do
          other = deploys(:succeeded_test)
          other.update_column(:reference, 'v4.9')

          success!
          status.status.must_equal 'error'
          status.status_list[1][:description].must_equal(
            "v4.9, v4.10 was deployed to deploy groups in this stage by Staging, Production"
          )
        end
      end

      it "ignores when previous deploy was not a version" do
        deploy.update_column(:reference, 'master')
        success!
        status.status.must_equal 'success'
      end

      it "ignores when previous deploy was failed" do
        deploy.job.update_column(:status, 'faild')
        success!
        status.status.must_equal 'success'
      end
    end

    describe "with bad ref" do
      let(:reference) { '[/r' }
      let(:url) { "repos/#{stage.project.user_repo_part}/commits/%255B/r/status" }

      it "escapes the url" do
        failure!
        status.status.must_equal 'failure'
      end
    end
  end

  describe "#status_list" do
    it "returns list" do
      success!
      status.status_list.must_equal [{foo: "bar"}]
    end

    it "shows that github is waiting for statuses to come when non has arrived yet ... or none are set up" do
      stub_github_api(url, statuses: [], state: "pending")
      list = status.status_list
      list.map { |s| s[:state] }.must_equal ["pending"]
      list.first[:description].must_include "No status was reported"
    end

    it "returns failure on Reference when not found list for consistent status display" do
      failure!
      status.status_list.map { |s| s[:state] }.must_equal ["Reference"]
    end

    describe "when deploying a previous release" do
      deploying_a_previous_release

      it "merges" do
        success!
        status.status_list.must_equal [
          {foo: "bar"},
          {state: "Old Release", description: "v4.3 was deployed to deploy groups in this stage by Production"}
        ]
      end
    end
  end
end
