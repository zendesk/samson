require 'radar_client_rb'

class RadarDeployNotifier

  def self.started(deploy)
    client.status('DeployStarted').set(deploy.id, deploy) if enabled?
    Rails.logger.info("Sent DeployStarted Radar msg for #{deploy.id}")
  rescue => ex
    Rails.logger.error("Failed to send Radar notification: #{ex.message}")
  end

  def self.finished(deploy)
    client.status('DeployFinished').set(deploy.id, deploy) if enabled?
    Rails.logger.info("Sent DeployFinished Radar msg for #{deploy.id}")
  rescue => ex
    Rails.logger.error("Failed to send Radar notification: #{ex.message}")
  end

  private

  def self.client
    Radar::Client.new('samson')
  end

  def self.enabled?
    ENV.has_key?('ENABLE_RADAR')
  end
end