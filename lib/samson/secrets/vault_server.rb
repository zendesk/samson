# frozen_string_literal: true
require 'vault'

module Samson
  module Secrets
    class VaultServer < ActiveRecord::Base
      NON_CONNECTION_ATTRIBUTES = ["name", "updated_at", "created_at"].freeze

      audited
      include AttrEncryptedSupport
      self.table_name = :vault_servers
      ADDRESS_PATTERN = /\Ahttps?:\/\//.freeze

      DEFAULT_CLIENT_OPTIONS = {
        use_ssl: true,
        timeout: 5,
        ssl_timeout: 3,
        open_timeout: 3,
        read_timeout: 2
      }.freeze

      has_many :deploy_groups, dependent: :nullify

      attribute :token
      attr_encrypted :token

      validates :name, presence: true, uniqueness: {case_sensitive: false}
      validates :address, presence: true, format: ADDRESS_PATTERN
      validate :validate_cert
      validate :validate_connection

      after_commit :refresh_vault_clients
      after_commit :expire_secrets_cache

      def cert_store
        return unless ca_cert?
        cert_store = OpenSSL::X509::Store.new
        cert_store.add_cert(OpenSSL::X509::Certificate.new(ca_cert))
        cert_store
      end

      def client
        @client ||= create_client
      end

      # Sync all data from one server to another
      # making sure not to leak for example production credentials to a test environment
      # and using raw access to write only to the correct server
      def sync!(other)
        allowed_envs = deploy_groups.map(&:environment).map(&:permalink) << 'global'
        allowed_groups = deploy_groups.map(&:permalink) << 'global'

        keys = other.client.kv.list_recursive

        # we can only write the keys that are allowed to live in this server
        keys.select! do |key|
          scope = Samson::Secrets::Manager.parse_id(key)
          allowed_envs.include?(scope.fetch(:environment_permalink)) &&
            allowed_groups.include?(scope.fetch(:deploy_group_permalink))
        end

        Samson::Parallelizer.map(keys.each_slice(100).to_a) do |keys|
          # create new clients to avoid any kind of blocking or race conditions
          other_client = other.create_client
          local_client = create_client

          keys.each do |key|
            secret = other_client.kv.read(key).data
            local_client.kv.write(key, secret)
          end
        end
      end

      def create_client
        VaultClientWrapper.new(
          DEFAULT_CLIENT_OPTIONS.merge(
            address: address,
            ssl_cert_store: cert_store,
            ssl_verify: tls_verify,
            token: token,
            versioned_kv: versioned_kv?
          )
        )
      end

      private

      def expire_secrets_cache
        return if (previous_changes.keys - NON_CONNECTION_ATTRIBUTES).empty?
        Samson::Secrets::Manager.expire_lookup_cache
      end

      def validate_cert
        cert_store
      rescue OpenSSL::OpenSSLError
        errors.add :ca_cert, "is invalid: #{$!.message}"
      end

      def validate_connection
        return if errors.any? # no need to blow up / wait if we know things are invalid
        client.kv.list
      rescue Vault::VaultError
        errors.add :base, "Unable to connect to server:\n#{$!.message}"
      end

      def refresh_vault_clients
        VaultClientManager.instance.expire_clients
      end
    end
  end
end
