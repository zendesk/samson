# frozen_string_literal: true
Samson::Periodical.register :stop_expired_deploys, "Stop deploys when buddy approval request timed out" do
  BuddyCheck.stop_expired_deploys
end

Samson::Periodical.register :renew_vault_token, "Renew vault token" do
  Samson::Secrets::VaultClient.client.renew_token
end

Samson::Periodical.register :remove_expired_locks, "Remove expired locks" do
  Lock.remove_expired_locks
end

if ENV['SERVER_MODE']
  Rails.application.config.after_initialize { Samson::Periodical.run }
end
