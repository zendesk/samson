class SlackWebhook < ActiveRecord::Base
  validate :validate_url

  belongs_to :stage

  private

  def validate_url
    valid = webhook_url.start_with?('http') && begin
      URI.parse(webhook_url)
    rescue URI::InvalidURIError
      false
    end

    errors.add(:webhook_url, "is invalid") unless valid
  end
end
