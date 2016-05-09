require 'attr_encrypted'
module SecretStorage
  class DbBackend
    class Secret < ActiveRecord::Base
      self.table_name = :secrets
      self.primary_key = :id # uses a string id

      ENCRYPTION_KEY = Rails.application.secrets.secret_key_base

      attr_encrypted :value, key: ENCRYPTION_KEY, algorithm: 'aes-256-cbc'

      before_validation :store_encryption_key_sha
      validates :id, :encrypted_value, :encryption_key_sha, presence: true
      validates :id, format: /\A\S+\/\S*\Z/

      private

      def store_encryption_key_sha
        self.encryption_key_sha = Digest::SHA2.hexdigest(ENCRYPTION_KEY)
      end
    end

    def self.read(key)
      secret = Secret.find(key)
      {
        key: key,
        updater_id: secret.updater_id,
        creator_id: secret.creator_id,
        updated_at: secret.updated_at,
        created_at: secret.created_at,
        value: secret.value
      }
    end

    def self.write(key, data)
      secret = Secret.where(id: key).first_or_initialize
      secret.updater_id = data.fetch(:user_id)
      secret.creator_id ||= data.fetch(:user_id)
      secret.value = data.fetch(:value)
      secret.save
    end

    def self.delete(key)
      Secret.delete(key)
    end

    def self.keys
      Secret.order(:id).pluck(:id)
    end
  end

  class HashicorpVault

    VAULT_SECRET_BACKEND ='secret/'.freeze
    # we don't really want other directories in here,
    # and there may be other chars that we find we don't like
    ENCODINGS = {"/": "%2F"}

    def self.read(key)
      result = Vault.logical.read(vault_path(key))
      raise(ActiveRecord::RecordNotFound) if result.data[:vault].nil?
      result = result.to_h
      result = result.merge(result.delete(:data))
      result[:value] = result.delete(:vault)
      result
    end

    def self.write(key, data)
      Vault.logical.write(vault_path(key), vault: data[:value])
    end

    def self.delete(key)
      Vault.logical.delete(vault_path(key))
    end

    def self.keys()
      Vault.logical.list(VAULT_SECRET_BACKEND).map! { |key| convert_path(key, :decode) }
    end

    private

    def self.vault_path(key)
      VAULT_SECRET_BACKEND + convert_path(key, :encode)
    end

    def self.convert_path(string, direction)
      string = string.dup
      if direction == :decode
        ENCODINGS.each { |k, v| string.gsub!(v.to_s, k.to_s) }
      elsif direction == :encode
        ENCODINGS.each { |k, v| string.gsub!(k.to_s, v.to_s) }
      else
        raise ArgumentError.new("direction is required")
      end
      string
    end
  end

  def self.allowed_project_prefixes(user)
    allowed = user.administrated_projects.pluck(:permalink)
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

    def read(key, include_secret: false)
      data = backend.read(key) || raise(ActiveRecord::RecordNotFound)
      data.delete(:value) unless include_secret
      data
    end

    def backend
      BACKEND
    end
  end
end
