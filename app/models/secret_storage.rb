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
      validates_presence_of :deploy_group_id, :environment_id

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
      secret.deploy_group_id = SecretStorage::permalink_id('deploy_group', data[:deploy_group_permalink])
      secret.environment_id = SecretStorage::permalink_id('enviorment', data[:enviorment_permalink])
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

    # get and cache a copy of the client that has a token
    def self.vault_client
      @vault_client || VaultClient.new
    end

    def self.read(key)
      result = vault_client.logical.read(VAULT_SECRET_BACKEND + key)
      raise(ActiveRecord::RecordNotFound) if result.data[:vault].nil?
      result = result.to_h
      result = result.merge(result.delete(:data))
      result[:value] = result.delete(:vault)
      result
    end

    def self.write(key, data)
      key = key.split('/', 4).last
      vault_client.logical.write(vault_path(key, data[:enviorment_permalink], data[:deploy_group_permalink], data[:project_permalink]), vault: data[:value])
    end

    def self.delete(key)
      vault_client.logical.delete(VAULT_SECRET_BACKEND + key)
    end

    def self.keys()
      base_keys = vault_client.logical.list(VAULT_SECRET_BACKEND)
      base_keys = keys_recursive(base_keys)
      base_keys.map! { |secret_path| convert_path(secret_path, :decode) }
    end

    private

    def self.keys_recursive(keys)
      until all_leaf_nodes?(keys)
        keys.each do |key|
          vault_client.logical.list(VAULT_SECRET_BACKEND + key).map.with_index do |new_key, pos|
            keys << key + new_key
          end
          # nuke the key if it's a dir and we have processed it.
          keys.delete(key) if key[-1] == '/'
        end
      end
      keys
    end

    def self.all_leaf_nodes?(tree)
      tree.all? { |node| node.to_s[-1] != '/' }
    end

    # path for these should be /env/project/deploygroup/key
    def self.vault_path(key, enviornment, deploy_group, project)
      VAULT_SECRET_BACKEND + enviornment.to_s + "/" + project.to_s + "/" + deploy_group.to_s + "/" + convert_path(key, :encode)
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
    allowed.unshift 'global' if user.is_admin?
    allowed
  end

  def self.permalink_id(link_type, link)
    return DeployGroup.find_by_permalink(link).id if link_type == 'deploy_group'
    return Environment.find_by_permalink(link).id if link_type == 'enviorment'
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
