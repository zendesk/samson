Stage.class_eval do

  has_many :slack_webhooks
  accepts_nested_attributes_for :slack_webhooks, allow_destroy: true, reject_if: :no_name_or_webhook_url?

  def send_slack_notifications?
    slack_webhooks.any?
  end

  def webhook_url
    slack_webhooks.first.try(:webhook_url)
  end

  def no_name_or_webhook_url?(slack_webhook_attrs)
    slack_webhook_attrs['name'].blank? || slack_webhook_attrs['webhook_url'].blank?
  end

end
