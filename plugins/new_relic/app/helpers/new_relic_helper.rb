# frozen_string_literal: true
module NewRelicHelper
  def newrelic_enabled_for_deploy?
    SamsonNewRelic.enabled? && @deploy.stage.new_relic_applications.any?
  end
end
