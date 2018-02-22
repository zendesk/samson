# frozen_string_literal: true
require 'vault'

# replace once https://github.com/hashicorp/vault-ruby/pull/118 is released
# using a monkey patch so `vault_action :list_recursive` works nicely in the backend
Vault::Logical.class_eval do
  def list_recursive(path, root = true)
    keys = list(path).flat_map do |p|
      full = +"#{path}#{p}"
      if full.end_with?("/")
        list_recursive(full, false)
      else
        full
      end
    end
    keys.each { |k| k.slice!(0, path.size) } if root
    keys
  end
end

module Samson
  module Secrets
    class VaultServer < ActiveRecord::Base
      PREFIX = ENV['VAULT_PREFIX'] || 'secret/apps/'

      audited
      include AttrEncryptedSupport
      self.table_name = :vault_servers
      ADDRESS_PATTERN = /\Ahttps?:\/\//

      DEFAULT_CLIENT_OPTIONS = {
        use_ssl: true,
        timeout: 5,
        ssl_timeout: 3,
        open_timeout: 3,
        read_timeout: 2
      }.freeze

      has_many :deploy_groups

      attribute :token
      attr_encrypted :token

      validates :name, presence: true, uniqueness: true
      validates :address, presence: true, format: ADDRESS_PATTERN
      validate :validate_cert
      validate :validate_connection

      after_save :refresh_vault_clients

      def cert_store
        return unless ca_cert.present?
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

        keys = other.client.logical.list_recursive(PREFIX)

        # we can only write the keys that are allowed to live in this server
        keys.select! do |key|
          scope = Samson::Secrets::Manager.parse_id(key.sub(PREFIX, ''))
          allowed_envs.include?(scope.fetch(:environment_permalink)) &&
            allowed_groups.include?(scope.fetch(:deploy_group_permalink))
        end

        Samson::Parallelizer.map(keys.each_slice(100).to_a) do |keys|
          # create new clients to avoid any kind of blocking or race conditions
          other_client = other.create_client
          local_client = create_client

          keys.each do |key|
            namespaced_key = "#{PREFIX}#{key}"
            secret = other_client.logical.read(namespaced_key).data
            local_client.logical.write(namespaced_key, secret)
          end
        end
      end

      def create_client
        Vault::Client.new(
          DEFAULT_CLIENT_OPTIONS.merge(
            ssl_verify: tls_verify,
            token: token,
            address: address,
            ssl_cert_store: cert_store
          )
        )
      end

      private

      def validate_cert
        cert_store
      rescue OpenSSL::OpenSSLError
        errors.add :ca_cert, "is invalid: #{$!.message}"
      end

      def validate_connection
        return if errors.any? # no need to blow up / wait if we know things are invalid
        client.logical.list(PREFIX)
      rescue Vault::VaultError
        errors.add :base, "Unable to connect to server:\n#{$!.message}"
      end

      def refresh_vault_clients
        VaultClient.client.expire_clients
      end
    end
  end
end
