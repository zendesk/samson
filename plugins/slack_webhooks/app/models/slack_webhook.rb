# frozen_string_literal: true
class SlackWebhook < ActiveRecord::Base
  validate :validate_url

  belongs_to :stage

  scope :for_buddy, -> { where(for_buddy: true) }

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
