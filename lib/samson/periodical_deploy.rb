# frozen_string_literal: true

module Samson
  module PeriodicalDeploy
    # do not change, used in db/migrate/20170728231915_add_daily_deploymemnt_to_stages.rb
    EXTERNAL_ID = "periodical deploy"

    def self.run
      Rails.logger.info "Periodical deploy start"
      deployer = User.where(external_id: EXTERNAL_ID).first!

      Stage.where(periodical_deploy: true).find_each do |stage|
        begin
          prefix = "Periodical deploy #{stage.project.permalink}/#{stage.permalink}:"
          unless deploy = stage.last_deploy
            Rails.logger.warn("#{prefix} skipping, never was deployed")
            next
          end
          unless deploy.succeeded?
            Rails.logger.warn("#{prefix} skipping, #{deploy.status}")
            next
          end

          deploy = DeployService.new(deployer).deploy(
            stage,
            reference: deploy.reference,
            buddy_id: deploy.buddy_id || deploy.job.user_id
          )
          Rails.logger.info("#{prefix} created #{deploy.url}")
        rescue StandardError => e
          ErrorNotifier.notify(e)
        end
      end
    end
  end
end
