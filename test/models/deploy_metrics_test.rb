# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployMetrics do
  let(:now) { Time.now }
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:user) { users(:deployer) }
  let(:deploy) { deploys(:succeeded_test) }
  let(:deploy_metrics) { DeployMetrics.new(deploy) }

  describe "#cycle_time" do
    describe "production deployment with no staging deployment" do
      let(:deploy) { deploys(:succeeded_production_test) }
      let(:deploy_metrics) { DeployMetrics.new(deploy) }
      before do
        deploy.updated_at = now + 25
        deploy.changeset.expects(:pull_requests).
          returns([stub("commit 1", created_at: now), stub("commit 2", created_at: now + 10)])
      end

      it "returns pr_production cycle time" do
        deploy_metrics.cycle_time[:pr_production].must_equal 20
      end

      it "returns nil for staging_production cycle time" do
        deploy_metrics.cycle_time[:staging_production].must_equal nil
      end
    end

    describe "production deployment with staging deployment" do
      let(:deploy1) do
        create_deploy!(reference: deploy.commit, stage: stages(:test_production), updated_at: now + 25)
      end
      let(:deploy2) do
        create_deploy!(reference: deploy1.commit, stage: stages(:test_production), updated_at: now + 50)
      end
      let(:deploy_metrics) { DeployMetrics.new(deploy2) }
      before do
        deploy2.changeset.expects(:pull_requests).
          returns([stub("commit 1", created_at: now), stub("commit 2", created_at: now + 10)])
      end

      it "returns pr_production cycle time" do
        deploy_metrics.cycle_time[:pr_production].must_equal 45
      end

      it "returns staging_production cycle time" do
        expected = deploy1.updated_at.to_i - deploy.updated_at.to_i
        deploy_metrics.cycle_time[:staging_production].must_equal expected
      end
    end

    describe "production deployment with no changes deployed" do
      let(:deploy) { deploys(:succeeded_production_test) }
      let(:deploy_metrics) { DeployMetrics.new(deploy) }
      before do
        deploy.updated_at = now + 25
        deploy.changeset.expects(:pull_requests).returns([])
      end

      it "returns nil for pr_production cycle time" do
        deploy_metrics.cycle_time[:pr_production].must_equal nil
      end

      it "returns nil for staging_production cycle time" do
        deploy_metrics.cycle_time[:staging_production].must_equal nil
      end
    end

    describe "production deployment with unsuccessful staging deployment" do
      let(:deploy) { deploys(:failed_staging_test) }
      let(:deploy1) do
        create_deploy!(reference: deploy.commit, stage: stages(:test_production), updated_at: now + 25)
      end
      let(:deploy_metrics) { DeployMetrics.new(deploy1) }
      before do
        deploy1.changeset.expects(:pull_requests).
          returns([stub("commit 1", created_at: now), stub("commit 2", created_at: now + 10)])
      end

      it "returns pr_production cycle time" do
        deploy_metrics.cycle_time[:pr_production].must_equal 20
      end

      it "returns nil for staging_production cycle time if no successful staging deployment" do
        deploy_metrics.cycle_time[:staging_production].must_equal nil
      end
    end

    describe "staging deployment" do
      it "returns {} for cycle time" do
        deploy_metrics.cycle_time.blank?.must_equal true
      end
    end
  end

  def create_deploy!(attrs = {})
    default_attrs = {
      reference: "baz",
      job: create_job!(commit: attrs[:reference]),
      project: project
    }

    deploy_stage = attrs.delete(:stage) || stage

    deploy_stage.deploys.create!(default_attrs.merge(attrs))
  end

  def create_job!(attrs = {})
    default_attrs = {
      project: project,
      command: "echo hello world",
      status: "succeeded",
      user: user
    }

    Job.create!(default_attrs.merge(attrs))
  end
end
