# frozen_string_literal: true
class RollbarWebhook < ActiveRecord::Base
  belongs_to :stage
  validates :webhook_url, :access_token, :environment, presence: true
  validate :validate_secret_exists

  def resolved_access_token
    if key = access_token.to_s.dup.sub!(TerminalExecutor::SECRET_PREFIX, "")
      Samson::Secrets::KeyResolver.new(stage.project, []).read(key)
    else
      access_token
    end
  end

  private

  def validate_secret_exists
    return if errors[:access_token].any?
    return if resolved_access_token
    errors.add :access_token, "unable to resolve secret (is it global/<project>/global ? / does it exist ?)"
  end
end
