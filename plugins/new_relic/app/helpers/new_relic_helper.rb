module NewRelicHelper
  def newrelic_enabled_for_deploy?
    SamsonNewRelic::Api::KEY && @deploy.stage.new_relic_applications.any?
  end
end
