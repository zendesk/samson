namespace :deploys do
  desc "Stop deploys that remain too long in a pending state"
  task stop_expired_deploys: :environment do
    BuddyCheck.stop_expired_deploys
  end
end
