# frozen_string_literal: true
# cache values depending on if a model changes, without adding callback-soup
# this only works because samson is 1-process app
# and otherwise would need a cache-store to synchronize
# we expire the cache every 5 minutes to be safe from untracked caches
# or changes on the commandline/cron/db etc
module Samson
  module ModelCache
    # every model has to register itself when getting loaded
    # so we clear the cache on auto-reload
    def self.track(model)
      @caches ||= {}
      model.after_save { Samson::ModelCache.expire(model) }
      model.after_destroy { Samson::ModelCache.expire(model) }
      expire(model)
    end

    def self.cache(model, key, &block)
      model_cache = @caches.fetch(model.name.to_sym)
      model_cache.fetch(key, &block)
    end

    def self.expire(model = nil)
      keys = (model ? [model.name.to_sym] : (@caches || {}).keys)
      keys.each do |key|
        @caches[key] = ActiveSupport::Cache::MemoryStore.new(expires_in: 5.minutes)
      end
    end
  end
end
