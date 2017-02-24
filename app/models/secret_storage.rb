# frozen_string_literal: true
module SecretStorage
  SECRET_KEYS_PARTS = [:environment_permalink, :project_permalink, :deploy_group_permalink, :key].freeze
  SEPARATOR = "/"

  def self.allowed_project_prefixes(user)
    allowed = user.administrated_projects.pluck(:permalink).sort
    allowed.unshift 'global' if user.admin?
    allowed
  end

  SECRET_KEY_REGEX = %r{[\w\/-]+}
  SECRET_KEYS_CACHE = 'secret_storage_keys'

  # keeps older lookups working
  DbBackend = Samson::Secrets::DbBackend
  HashicorpVault = Samson::Secrets::HashicorpVaultBackend

  BACKEND = ENV.fetch('SECRET_STORAGE_BACKEND', 'Samson::Secrets::DbBackend').constantize

  class << self
    def write(key, data)
      return false unless key =~ /\A#{SECRET_KEY_REGEX}\z/
      return false if data.blank? || data[:value].blank?
      result = backend.write(key, data)
      modify_keys_cache { |c| c.push key unless c.include?(key) }
      result
    end

    # reads a single key and raises ActiveRecord::RecordNotFound if it is not found
    def read(key, include_value: false)
      data = backend.read(key) || raise(ActiveRecord::RecordNotFound)
      data.delete(:value) unless include_value
      data
    end

    def exist?(key)
      !!(backend.read_multi([key]).values.map(&:nil?) == [false])
    end

    # reads multiple keys from the backend into a hash, not raising on missing
    # [a, b, c] -> {a: 1, c: 2}
    def read_multi(keys, include_value: false)
      data = backend.read_multi(keys)
      data.each_value { |s| s.delete(:value) } unless include_value
      data
    end

    def delete(key)
      result = backend.delete(key)
      modify_keys_cache { |c| c.delete(key) }
      result
    end

    def keys
      Rails.cache.fetch(SECRET_KEYS_CACHE) { backend.keys }
    end

    def backend
      BACKEND
    end

    def generate_secret_key(data)
      SECRET_KEYS_PARTS.map { |k| data.fetch(k) }.join(SEPARATOR)
    end

    def parse_secret_key(key)
      SECRET_KEYS_PARTS.zip(key.split(SEPARATOR, SECRET_KEYS_PARTS.size)).to_h
    end

    private

    def modify_keys_cache
      if cache = Rails.cache.read(SECRET_KEYS_CACHE)
        yield cache
        Rails.cache.write(SECRET_KEYS_CACHE, cache)
      end
    end
  end
end
