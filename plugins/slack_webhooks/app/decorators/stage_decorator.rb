# frozen_string_literal: true
Stage.class_eval do
  has_many :slack_webhooks
  accepts_nested_attributes_for :slack_webhooks, allow_destroy: true, reject_if: :no_webhook_url?

  def slack_buddy_channels
    @slack_buddy_channels ||= slack_webhooks.for_buddy.pluck(:channel)
  end

  def send_slack_buddy_request?
    slack_buddy_channels.any?
  end

  def send_slack_webhook_notifications?
    slack_webhooks.any?
  end

  private

  def no_webhook_url?(slack_webhook_attrs)
    slack_webhook_attrs['webhook_url'].blank?
  end
end
