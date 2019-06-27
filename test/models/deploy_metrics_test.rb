# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployMetrics do
  let(:deploy) { deploys(:succeeded_production_test) }
  let(:staging_deploy) { deploys(:succeeded_test) }
  let(:cycle_time) { DeployMetrics.new(deploy).cycle_time }

  describe "#cycle_time" do
    before do
      # stop time to avoid random test errors
      now = Time.now
      Time.stubs(:now).returns(now)
      deploy.update_column(:updated_at, now - 25)

      # make staging deploy match deploy
      staging_deploy.job.update_column(:commit, deploy.commit)
      staging_deploy.update_column(:updated_at, now - 50)

      # fake some PRs
      deploy.changeset.stubs(:pull_requests).
        returns(
          [
            stub("commit 1", created_at: now - 30),
            stub("commit 2", created_at: now - 50)
          ]
        )
    end

    it "reports cycle times" do
      cycle_time.must_equal(
        pr_production: 15, # (30 - 25 + 50 - 25) / 2
        staging_production: 25
      )
    end

    it "ignores failed deploys" do
      deploy.job.update_column(:status, "failed")
      cycle_time.must_equal({})
    end

    it "ignores non-production deploys" do
      deploy.stage = stages(:test_staging)
      cycle_time.must_equal({})
    end

    it "does not report staging_production when there was no staging deploy" do
      staging_deploy.job.update_column(:commit, 'a' * 40)
      cycle_time.must_equal(pr_production: 15)
    end

    it "does not report when this was not the first production deploy" do
      other = deploys(:failed_staging_test)
      other.update_columns(stage_id: deploy.stage_id, id: deploy.id - 1)
      other.job.update_columns(commit: deploy.commit, status: "succeeded")
      cycle_time.must_equal({})
    end

    it "does not report PR time when there are no PRs" do
      deploy.changeset.pull_requests.clear
      cycle_time.must_equal(staging_production: 25)
    end
  end
end
