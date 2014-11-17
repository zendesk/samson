require 'radar_client_rb'

class RadarDeployNotifier

  def self.send_deploy_status(deploy, status)
    message_type = case status
                     when :started
                       'DeployStarted'
                     when :created
                       'DeployCreated'
                     when :finished
                       'DeployFinished'
                     else
                       status.to_s
                   end
    client.status(message_type).set(deploy.id, deploy) if enabled?
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