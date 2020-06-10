# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Samson::PeriodicalDeploy do
  describe ".run" do
    let(:stage) { stages(:test_staging) }
    let!(:deployer) do
      # must be in sync with db/migrate/20170728231915_add_daily_deploymemnt_to_stages.rb
      User.create!(
        external_id: Samson::PeriodicalDeploy::EXTERNAL_ID,
        name: "Periodical Deployer",
        integration: true,
        role_id: Role::DEPLOYER.id
      )
    end

    before do
      stage.update_column :periodical_deploy, true
      stage.last_deploy.job.update_column :status, 'succeeded'
      stage.last_deploy.update_column :buddy_id, users(:admin).id
    end

    it "deploys periodical stages" do
      assert_difference "stage.deploys.count", +1 do
        Samson::PeriodicalDeploy.run
      end
      deploy = stage.deploys.first
      deploy.reference.must_equal "staging"
      deploy.buddy.must_equal users(:admin)
    end

    it "does not deploy failed deploys" do
      stage.last_deploy.job.update_column :status, 'failed'
      refute_difference "stage.deploys.count" do
        Samson::PeriodicalDeploy.run
      end
    end

    it "does not deploy if stage was never deployed" do
      stage.deploys.delete_all
      refute_difference "stage.deploys.count" do
        Samson::PeriodicalDeploy.run
      end
    end

    it "fails when there is no periodical deploy user" do
      deployer.delete
      assert_raises ActiveRecord::RecordNotFound do
        Samson::PeriodicalDeploy.run
      end
    end

    it "skips when single stage is in trouble" do
      Samson::ErrorNotifier.expects(:notify)
      DeployService.expects(:new).raises("Whoops")
      refute_difference "stage.deploys.count" do
        Samson::PeriodicalDeploy.run
      end
    end
  end
end
