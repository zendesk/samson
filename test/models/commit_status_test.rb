# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 1

describe CommitStatus do
  def self.deploying_a_previous_release
    let(:reference) { 'v4.2' }
    let(:deploy) { deploys(:succeeded_production_test) }

    before do
      DeployGroup.stubs(enabled?: true)
      dg = deploy_groups(:pod1)
      dg.update_column(:environment_id, environments(:staging).id)
      stage.deploy_groups << dg
      deploy.update_column(:reference, 'v4.3')
    end
  end

  def success!
    stub_github_api(url, statuses: [{foo: "bar"}], state: "success")
  end

  def failure!
    stub_github_api(url, nil, 404)
  end

  def status(stage_param: stage, reference_param: reference)
    @status ||= CommitStatus.new(stage_param, reference_param)
  end

  let(:stage) { stages(:test_staging) }
  let(:reference) { 'master' }
  let(:url) { "repos/#{stage.project.repository_path}/commits/#{reference}/status" }

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
        assert_sql_queries 10 do
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
      let(:url) { "repos/#{stage.project.repository_path}/commits/%255B/r/status" }

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

  describe "#resolve_states" do
    it 'picks the first state if it has higher priority' do
      status.send(:pick_highest_state, 'error', 'success').must_equal 'error'
    end

    it 'picks the second state if it has higher priority' do
      status.send(:pick_highest_state, 'success', 'error').must_equal 'error'
    end

    it 'returns second state if first state is nil' do
      status.send(:pick_highest_state, nil, 'pending').must_equal 'pending'
    end
  end

  describe '#ref_statuses' do
    let(:production_stage) { stages(:test_production) }

    it 'returns nothing if stage is not production' do
      status.send(:ref_statuses).must_equal []
    end

    it 'returns nothing if ref has been deployed to non-production stage' do
      production_stage.project.expects(:deployed_reference_to_non_production_stage?).returns(true)

      status(stage_param: production_stage).send(:ref_statuses).must_equal []
    end

    it 'returns status if ref has not been deployed to non-production stage' do
      production_stage.project.expects(:deployed_reference_to_non_production_stage?).returns(false)

      expected_hash = [
        {
          state: "pending",
          statuses: [
            {
              state: "Production Only Reference",
              description: "master has not been deployed to a non-production stage."
            }
          ]
        }
      ]

      status(stage_param: production_stage).send(:ref_statuses).must_equal expected_hash
    end

    it 'includes plugin statuses' do
      Samson::Hooks.expects(:fire).with(:ref_status, stage, reference).returns([{foo: :bar}])

      status.send(:ref_statuses).must_equal [{foo: :bar}]
    end
  end

  #def maxitest_timeout;false;end
end
