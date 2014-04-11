require 'zendesk_api'

class ZendeskNotification
  cattr_accessor(:token) { ENV['CLIENT_SECRET'] }
  cattr_accessor(:zendesk_url) { ENV['ZENDESK_URL'] }

  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
  end

  def deliver
    zendesk_tickets = @deploy.changeset.zendesk_tickets

    zendesk_tickets.each do |ticket_id|
      attributes = {
        :id => ticket_id,
        :status => "open",
        :comment => {:value => content(ticket_id), :public => false }
      }

      if zendesk_client.tickets.update(attributes)
        Rails.logger.info "Updated Zendesk ticket: #{ticket_id} with a comment"
      else
        Rails.logger.warn("Failed to modify ticket with GitHub update: #{ticket.errors}")
      end
    end
  end

  private

  def zendesk_client
    @zendesk_client ||= ZendeskAPI::Client.new do |config|
      config.token = token
      config.url = "#{zendesk_url}/api/v2"
      config.username = "#{@deploy.user.email}"
    end
  end

  def content(ticket_id)
    @content = ZendeskNotificationRenderer.render(@deploy, ticket_id)
  end
end
