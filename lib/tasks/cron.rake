# frozen_string_literal: true
namespace :deploys do
  desc "Stop deploys when buddy approval request timed out"
  task stop_expired_deploys: :environment do
    BuddyCheck.stop_expired_deploys
  end
end

namespace :vault do
  desc "Renew vault token"
  task renew_vault_token: :environment do
    Samson::Secrets::VaultClient.client.renew_token
  end
end
