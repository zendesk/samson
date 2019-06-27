# frozen_string_literal: true
class RollbarWebhook < ActiveRecord::Base
  belongs_to :stage, inverse_of: :rollbar_webhooks
  validates :webhook_url, :access_token, :environment, presence: true
  validate :validate_secret_exists

  private

  def validate_secret_exists
    return if errors[:access_token].any?
    key_resolver = Samson::Secrets::KeyResolver.new(stage.project, [])
    return if key_resolver.resolved_attribute(access_token)
    errors.add :access_token, "unable to resolve secret (is it global/<project>/global ? / does it exist ?)"
  end
end
