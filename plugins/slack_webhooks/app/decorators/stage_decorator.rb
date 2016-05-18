Stage.class_eval do
  has_many :slack_webhooks
  accepts_nested_attributes_for :slack_webhooks, allow_destroy: true, reject_if: :no_webhook_url?

  def send_slack_webhook_notifications?
    slack_webhooks.any?
  end

  def no_webhook_url?(slack_webhook_attrs)
    slack_webhook_attrs['webhook_url'].blank?
  end
end
