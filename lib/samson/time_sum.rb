# frozen_string_literal: true

# summarize activesupport notification duration into user defined buckets
module Samson
  module TimeSum
    BASE = {
      "execute.command_executor.samson" => :shell,
      "execute.terminal_executor.samson" => :shell,
      "request.rest_client.samson" => :kubeclient,
      "request.vault.samson" => :vault,
      "request.faraday.samson" => :http,
      "sql.active_record" => :db
    }.freeze

    def self.record(metrics = BASE, &block)
      sum = metrics.each_value.each_with_object({}) { |key, h| h[key] = 0.0 }
      summarize = ->(metric, start, finish, *) { sum[metrics[metric]] += 1000 * (finish - start) }
      metrics.each_key.inject(block) do |inner, name|
        -> { ActiveSupport::Notifications.subscribed(summarize, name, &inner) }
      end.call
      sum
    end

    def self.instrument(notification, payload)
      ActiveSupport::Notifications.instrument(notification, payload) do
        result = nil
        payload[:parts] = record(BASE) { result = yield }
        result
      end
    end
  end
end
