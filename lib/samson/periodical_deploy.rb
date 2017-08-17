# frozen_string_literal: true

module Samson
  module PeriodicalDeploy
    # do not change, used in db/migrate/20170728231915_add_daily_deploymemnt_to_stages.rb
    EXTERNAL_ID = "periodical deploy"

    def self.run
      # find all periodical stages
      Stage.where(periodical_deploy: true).all.each do |stage|
        # find out the latest deploy version
        next unless deploy = stage.last_deploy
        next unless deploy.succeeded?

        deployer = User.where(external_id: EXTERNAL_ID).first!
        DeployService.new(deployer).deploy(
          stage,
          reference: deploy.reference,
          buddy_id: deploy.buddy_id || deploy.job.user_id
        )
      end
    end
  end
end
