module NewRelicHelper
  def newrelic_enabled_for_deploy?
    NewRelicApi.api_key.present? && @deploy.stage.new_relic_applications.any?
  end
end
