# frozen_string_literal: true
require 'samson/periodical' # avoid auto-load since we setup global state

Samson::Periodical.register :cancel_stalled_builds, "Cancel stalled builds" do
  Build.cancel_stalled_builds
end

Samson::Periodical.register :stop_expired_deploys, "Cancel deploys when buddy approval request timed out" do
  Deploy.expired.each { |d| d.cancel(nil) }
end

Samson::Periodical.register :renew_vault_token, "Renew vault token" do
  Samson::Secrets::VaultClientManager.instance.renew_token
end

Samson::Periodical.register :remove_expired_locks, "Remove expired locks" do
  Lock.remove_expired_locks
end

Samson::Periodical.register :report_system_stats, "Report system stats" do
  # https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/ConnectionPool.html#method-i-stat
  conn_pool_stats = ActiveRecord::Base.connection_pool.stat
  memcached_available =
    if Rails.cache.instance_of?(ActiveSupport::Cache::MemoryStore)
      1
    else
      Rails.cache.instance_variable_get(:@data).with { |c| c.send(:ring).servers.count(&:alive?) }
    end

  ActiveSupport::Notifications.instrument(
    "system_stats.samson",
    thread_count: Thread.list.size,
    memcached_available: memcached_available,
    mysql_pool_busy: conn_pool_stats[:busy],
    mysql_pool_dead: conn_pool_stats[:dead],
    mysql_pool_idle: conn_pool_stats[:idle],
    mysql_pool_size: conn_pool_stats[:size],
    mysql_pool_wait: conn_pool_stats[:waiting]
  )
end

Samson::Periodical.register :periodical_deploy, "Deploy periodical stages", consistent_start_time: true do
  Samson::PeriodicalDeploy.run
end

Samson::Periodical.register :report_process_stats, "Report process stats" do
  Samson::ProcessUtils.report_to_statsd
end

Samson::Periodical.register :repo_provider_status, "Refresh repo provider status" do
  Samson::RepoProviderStatus.refresh
end

Samson::Periodical.register :global_command_cleanup, "Scope global commands to projects and delete unused" do
  Command.cleanup_global
end

if ENV['SERVER_MODE']
  Rails.application.config.after_initialize do
    Samson::Periodical.enabled = true
    Samson::Periodical.run
  end
end
