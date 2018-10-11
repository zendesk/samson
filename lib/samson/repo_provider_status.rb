# frozen_string_literal: true
module Samson
  class RepoProviderStatus
    CACHE_KEY = name

    class << self
      def errors
        (
          Rails.cache.read(CACHE_KEY) ||
          ["To see repo provider status information, add repo_provider_status:60 to PERIODICAL environment variable."]
        )
      end

      def refresh
        Rails.cache.write(CACHE_KEY, Samson::Hooks.fire(:repo_provider_status).compact)
      end
    end
  end
end
