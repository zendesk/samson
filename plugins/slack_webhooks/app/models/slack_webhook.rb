# frozen_string_literal: true
class SlackWebhook < ActiveRecord::Base
  before_validation :cleanup_channel
  validate :validate_url
  validate :validate_used

  belongs_to :stage, inverse_of: :slack_webhooks

  def deliver_for?(deploy_phase, deploy)
    case deploy_phase
    when :buddy_box then buddy_box?
    when :buddy_request then buddy_request?
    when :before_deploy then before_deploy?
    when :after_deploy then deploy.succeeded? ? on_deploy_success? : on_deploy_failure?
    else raise "Unknown phase #{deploy_phase.inspect}"
    end
  end

  private

  def validate_url
    valid = webhook_url&.start_with?('http') &&
      begin
        URI.parse(webhook_url)
      rescue URI::InvalidURIError
        false
      end

    errors.add(:webhook_url, "is invalid") unless valid
  end

  def cleanup_channel
    channel&.delete!('#')
  end

  def validate_used
    return if buddy_box || buddy_request || before_deploy || on_deploy_success || on_deploy_failure
    errors.add :base, "select at least one delivery time"
  end
end
