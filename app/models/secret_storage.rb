module SecretStorage
  require 'attr_encrypted'
  SECRET_KEYS_PARTS = [:environment, :project, :deploy_group, :key].freeze
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
    # we don't really want other directories in the key,
    # and there may be other chars that we find we don't like
    ENCODINGS = {"/": "%2F"}

    def self.read(key)
      safe_key = vault_path(
        SecretStorage.parse_secret_key_part(key, :environment),
        SecretStorage.parse_secret_key_part(key, :project),
        SecretStorage.parse_secret_key_part(key, :deploy_group),
        SecretStorage.parse_secret_key_part(key, :key),
      )
      result = vault_client.logical.read(safe_key)
      raise(ActiveRecord::RecordNotFound) if result.data[:vault].nil?
      result = result.to_h
      result = result.merge(result.delete(:data))
      result[:value] = result.delete(:vault)
      result
    end

    # and parse it
    def self.write(key, data)
      key = SecretStorage.parse_secret_key_part(key, :key)
      vault_client.logical.write(
        vault_path(
          data[:environment_permalink],
          data[:project_permalink],
          data[:deploy_group_permalink],
          key),
        vault: data[:value])
    end

    def self.delete(key)
      safe_key = vault_path(
        SecretStorage.parse_secret_key_part(key, :environment),
        SecretStorage.parse_secret_key_part(key, :project),
        SecretStorage.parse_secret_key_part(key, :deploy_group),
        SecretStorage.parse_secret_key_part(key, :key),
      )
      vault_client.logical.delete(safe_key)
    end

    def self.keys()
      base_keys = vault_client.logical.list(VAULT_SECRET_BACKEND)
      base_keys = keys_recursive(base_keys)
      base_keys.map! { |secret_path| convert_path(secret_path, :decode) }
    end

    private

    # get and cache a copy of the client that has a token
    def self.vault_client
      @vault_client ||= VaultClient.new
    end

    def self.keys_recursive(keys, key_path="")
      keys.flat_map do |key|
        new_key = key_path + key
        if key.end_with?('/') # a directory
          keys_recursive(vault_client.logical.list(VAULT_SECRET_BACKEND + new_key ), new_key)
        else
          new_key
        end
      end
    end

    # path for these should be /env/project/deploygroup/key
    def self.vault_path(environment, project, deploy_group, key)
      VAULT_SECRET_BACKEND + SecretStorage.generate_secret_key(environment, project, deploy_group, convert_path(key, :encode))
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

    def read(key, include_secret: false)
      data = backend.read(key) || raise(ActiveRecord::RecordNotFound)
      data.delete(:value) unless include_secret
      data
    end

    def backend
      BACKEND
    end

    def generate_secret_key(environment=nil, project=nil, deploy_group=nil, key=nil)
      if environment.nil?
        raise ArgumentError.new("missing environment paramater")
      end
      if project.nil?
        raise ArgumentError.new("missing project paramater")
      end
      if deploy_group.nil?
        raise ArgumentError.new("missing deploy_group paramater")
      end
      if key.nil?
        raise ArgumentError.new("missing key paramater")
      end
      environment.to_s + "/" + project.to_s + "/" + deploy_group.to_s + "/" + key.to_s
    end

    def parse_secret_key_part(key, part)
      return false if key.nil?
      index = SecretStorage::SECRET_KEYS_PARTS.index(part)
      key.split('/', SecretStorage::SECRET_KEYS_PARTS.count)[index]
    end
  end
end
