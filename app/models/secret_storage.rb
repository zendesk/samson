# frozen_string_literal: true
module SecretStorage
  SECRET_KEYS_PARTS = [:environment_permalink, :project_permalink, :deploy_group_permalink, :key].freeze
  SEPARATOR = "/"
  VAULT_SECRET_BACKEND = 'secret/'
  SAMSON_SECRET_NAMESPACE = 'apps/'

  require 'attr_encrypted'
  class DbBackend
    class Secret < ActiveRecord::Base
      self.table_name = :secrets
      self.primary_key = :id # uses a string id

      ENCRYPTION_KEY = Rails.application.secrets.secret_key_base

      attr_encrypted :value, key: ENCRYPTION_KEY, algorithm: 'aes-256-cbc'

      before_validation :store_encryption_key_sha
      validates :id, :encrypted_value, :encryption_key_sha, presence: true
      validates :id, format: %r{\A([^/\s]+/){3}[^\s]+\Z}

      private

      def store_encryption_key_sha
        self.encryption_key_sha = Digest::SHA2.hexdigest(ENCRYPTION_KEY)
      end
    end

    class << self
      def read(key)
        return unless secret = Secret.find_by_id(key)
        secret_to_hash secret
      end

      def read_multi(keys)
        secrets = Secret.where(id: keys).all
        secrets.each_with_object({}) { |s, a| a[s.id] = secret_to_hash(s) }
      end

      def write(key, data)
        secret = Secret.where(id: key).first_or_initialize
        secret.updater_id = data.fetch(:user_id)
        secret.creator_id ||= data.fetch(:user_id)
        secret.value = data.fetch(:value)
        secret.save
      end

      def delete(key)
        Secret.delete(key)
      end

      def keys
        Secret.order(:id).pluck(:id)
      end

      private

      def secret_to_hash(secret)
        {
          key: secret.id,
          updater_id: secret.updater_id,
          creator_id: secret.creator_id,
          updated_at: secret.updated_at,
          created_at: secret.created_at,
          value: secret.value
        }
      end
    end
  end

  class HashicorpVault
    # we don't really want other directories in the key,
    # and there may be other chars that we find we don't like
    ENCODINGS = {"/": "%2F"}.freeze

    class << self
      def read(key)
        key = vault_path(key)
        result = vault_client.read(key)
        return if !result || result.data[:vault].nil?

        result = result.to_h
        result = result.merge(result.delete(:data))
        result[:value] = result.delete(:vault)
        result
      end

      def read_multi(keys)
        keys.each_with_object({}) do |key, a|
          if value = read(key)
            a[key] = value
          end
        end
      end

      def write(key, data)
        vault_client.write(vault_path(key), vault: data[:value])
      end

      def delete(key)
        vault_client.delete(vault_path(key))
      end

      def keys
        keys = vault_client.list(VAULT_SECRET_BACKEND + SAMSON_SECRET_NAMESPACE)
        keys = keys_recursive(keys)
        keys.uniq! # we read from multiple backends that might have the same keys
        keys.map! do |secret_path|
          convert_path(secret_path, :decode) # FIXME: ideally only decode the key(#4) part
        end
      end

      private

      # get and cache a copy of the client that has a token
      def vault_client
        @vault_client ||= VaultClient.new
      end

      def keys_recursive(keys, key_path = "")
        keys.flat_map do |key|
          new_key = key_path + key
          if key.end_with?('/') # a directory
            keys_recursive(vault_client.list(VAULT_SECRET_BACKEND + SAMSON_SECRET_NAMESPACE + new_key), new_key)
          else
            new_key
          end
        end
      end

      # key is the last element and should not include bad characters
      def vault_path(key)
        parts = key.split(SEPARATOR, SECRET_KEYS_PARTS.size)
        parts[-1] = convert_path(parts[-1], :encode)
        VAULT_SECRET_BACKEND + SAMSON_SECRET_NAMESPACE + parts.join(SEPARATOR)
      end

      # convert from/to escaped characters
      def convert_path(string, direction)
        string = string.dup
        if direction == :decode
          ENCODINGS.each { |k, v| string.gsub!(v.to_s, k.to_s) }
        elsif direction == :encode
          ENCODINGS.each { |k, v| string.gsub!(k.to_s, v.to_s) }
        else
          raise ArgumentError, "direction is required"
        end
        string
      end
    end
  end

  def self.allowed_project_prefixes(user)
    allowed = user.administrated_projects.pluck(:permalink).sort
    allowed.unshift 'global' if user.admin?
    allowed
  end

  SECRET_KEY_REGEX = %r{[\w\/-]+}
  BACKEND = ENV.fetch('SECRET_STORAGE_BACKEND', 'SecretStorage::DbBackend').constantize

  class << self
    delegate :delete, :keys, to: :backend

    def write(key, data)
      return false unless key =~ /\A#{SECRET_KEY_REGEX}\z/
      return false if data.blank? || data[:value].blank?
      backend.write(key, data)
    end

    # reads a single key and raises ActiveRecord::RecordNotFound if it is not found
    def read(key, include_secret: false)
      data = backend.read(key) || raise(ActiveRecord::RecordNotFound)
      data.delete(:value) unless include_secret
      data
    end

    # reads multiple keys from the backend into a hash
    # [a, b, c] -> {a: 1, c: 2}
    def read_multi(keys, include_secret: false)
      data = backend.read_multi(keys)
      data.each_value { |s| s.delete(:value) } unless include_secret
      data
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
  end
end
