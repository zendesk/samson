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

    SECRET_BACKEND ='secret/'.freeze

    def self.read(key)
      result = Vault.logical.read(SECRET_BACKEND  + key)
      result.data[:secret_data]
    end

    def self.write(key, data)
      Vault.logical.write(SECRET_BACKEND + key, secret_data: data)
    end

    def self.delete(key)
      Vault.logical.delete(SECRET_BACKEND + key)
    end

    def self.keys()
      dirs = Vault.logical.list(SECRET_BACKEND)
      dirs.map do |dir|
        if dir =~ /.*\/$/
          dir += Vault.logical.list(SECRET_BACKEND + dir).pop
        end
      end
    end
  end

  def self.allowed_project_prefixes(user)
    allowed = user.administrated_projects.pluck(:permalink)
    allowed.unshift 'global' if user.is_admin?
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
