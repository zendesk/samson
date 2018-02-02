# frozen_string_literal: true
require 'samson/periodical' # avoid auto-load since we setup global state

Samson::Periodical.register :stop_expired_deploys, "Cancel deploys when buddy approval request timed out" do
  Deploy.expired.each { |d| d.cancel(nil) }
end

Samson::Periodical.register :renew_vault_token, "Renew vault token" do
  Samson::Secrets::VaultClient.client.renew_token
end

Samson::Periodical.register :remove_expired_locks, "Remove expired locks" do
  Lock.remove_expired_locks
end

Samson::Periodical.register :report_system_stats, "Report system stats" do
  memcached_available =
    if Rails.env.test?
      1
    else
      Rails.cache.instance_variable_get(:@data).send(:ring).servers.count(&:alive?)
    end

  ActiveSupport::Notifications.instrument(
    "system_stats.samson",
    thread_count: Thread.list.size,
    mysql_wait: ActiveRecord::Base.connection_pool.num_waiting_in_queue,
    memcached_available: memcached_available
  )
end

Samson::Periodical.register :periodical_deploy, "Deploy periodical stages", consistent_start_time: true do
  Samson::PeriodicalDeploy.run
end

if ENV['SERVER_MODE']
  Rails.application.config.after_initialize do
    Samson::Periodical.enabled = true
    Samson::Periodical.run
  end
end
