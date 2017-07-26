# frozen_string_literal: true
require 'digest/sha2'

module SecretStorage
  ID_PARTS = [:environment_permalink, :project_permalink, :deploy_group_permalink, :key].freeze
  ID_PART_SEPARATOR = "/"
  SECRET_ID_REGEX = %r{[\w\/-]+}
  SECRET_LOOKUP_CACHE = 'secret_lookup_cache'
  SECRET_LOOKUP_CACHE_MUTEX = Mutex.new

  def self.allowed_project_prefixes(user)
    allowed = user.administrated_projects.pluck(:permalink).sort
    allowed.unshift 'global' if user.admin?
    allowed
  end

  # keeps older lookups working
  DbBackend = Samson::Secrets::DbBackend
  HashicorpVault = Samson::Secrets::HashicorpVaultBackend

  BACKEND = ENV.fetch('SECRET_STORAGE_BACKEND', 'Samson::Secrets::DbBackend').constantize

  class << self
    def write(id, data)
      return false unless id =~ /\A#{SECRET_ID_REGEX}\z/
      return false if data.blank? || data[:value].blank?
      result = backend.write(id, data)
      modify_lookup_cache { |c| c[id] = lookup_cache_value(data) }
      result
    end

    # reads a single id and raises ActiveRecord::RecordNotFound if it is not found
    def read(id, include_value: false)
      data = backend.read(id) || raise(ActiveRecord::RecordNotFound)
      data.delete(:value) unless include_value
      data
    end

    def exist?(id)
      backend.read_multi([id]).values.map(&:nil?) == [false]
    end

    # reads multiple ids from the backend into a hash, not raising on missing
    # [a, b, c] -> {a: 1, c: 2}
    def read_multi(ids, include_value: false)
      data = backend.read_multi(ids)
      data.each_value { |s| s.delete(:value) } unless include_value
      data
    end

    def delete(id)
      result = backend.delete(id)
      modify_lookup_cache { |c| c.delete(id) }
      result
    end

    def ids
      lookup_cache.keys
    end

    def shareable_keys
      ids.map do |id|
        parts = SecretStorage.parse_id(id)
        parts.fetch(:key) if parts.fetch(:project_permalink) == "global"
      end.compact
    end

    def filter_ids_by_value(ids, value)
      value_hashed = hash_value(value)
      lookup_cache.slice(*ids).select { |_, v| v.fetch(:value_hashed) == value_hashed }.keys
    end

    def backend
      BACKEND
    end

    def generate_id(data)
      ID_PARTS.map { |k| data.fetch(k) }.join(ID_PART_SEPARATOR)
    end

    def parse_id(id)
      ID_PARTS.zip(id.split(ID_PART_SEPARATOR, ID_PARTS.size)).to_h
    end

    def sharing_grants?
      ENV['SECRET_STORAGE_SHARING_GRANTS']
    end

    private

    def lookup_cache
      SECRET_LOOKUP_CACHE_MUTEX.synchronize do
        Rails.cache.fetch(SECRET_LOOKUP_CACHE) do
          backend.ids.each_slice(1000).each_with_object({}) do |slice, all|
            read_multi(slice, include_value: true).each do |id, secret|
              all[id] = lookup_cache_value(secret)
            end
          end
        end
      end
    end

    def lookup_cache_value(secret)
      {
        value_hashed: hash_value(secret.fetch(:value))
      }
    end

    def hash_value(value)
      Digest::SHA2.hexdigest("#{Samson::Application.config.secret_key_base}#{value}").first(10)
    end

    def modify_lookup_cache
      SECRET_LOOKUP_CACHE_MUTEX.synchronize do
        cache = Rails.cache.read(SECRET_LOOKUP_CACHE) || {}
        yield cache
        Rails.cache.write(SECRET_LOOKUP_CACHE, cache)
      end
    end
  end
end
