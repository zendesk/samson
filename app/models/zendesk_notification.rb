require 'zendesk_api'

class ZendeskNotification
  cattr_accessor(:token) { ENV['CLIENT_SECRET']}
  cattr_accessor(:zendesk_url) { ENV['ZENDESK_URL']}
  cattr_accessor(:zendesk_user) { ENV['ZENDESK_USER']}

  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
  end

  def deliver
    zendesk_tickets = @deploy.changeset.zendesk_tickets

    zendesk_tickets.each do |ticket_id|
      ticket = zendesk_client.tickets.find(:id => ticket_id)

      # Update ticket just once with comment
      if !is_comment_added?(ticket)
        ticket.comment = {:value => body, :public => false }

        if ticket.save
          Rails.logger.info "Updated Zendesk ticket: #{ticket_id} with a comment"
        else
          Rails.logger.warn("Failed to modify ticket with GitHub update: #{ticket.errors}")
        end
      end
    end
  end

  private

  def zendesk_client
    @zendesk_client ||=ZendeskAPI::Client.new do |config|
      config.token = token
      config.url = "#{zendesk_url}/api/v2"
      config.username = zendesk_user
    end
  end

  def body
    "A fix for this issue has been deployed to #{@stage.name}"
  end

  def is_comment_added?(ticket)
    ticket.comments.map(&:body).include?(body)
  end
end
