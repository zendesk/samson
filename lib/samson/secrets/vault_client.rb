# frozen_string_literal: true
require 'vault'

module Samson
  module Secrets
    # Vault wrapper that sends requests to all matching vault servers
    # TODO: atm expects all keys to start with apps/secrets/
    class VaultClient
      CERT_AUTH_PATH = '/v1/auth/cert/login'
      DEFAULT_CLIENT_OPTIONS = {
        use_ssl: true,
        timeout: 5,
        ssl_timeout: 3,
        open_timeout: 3,
        read_timeout: 2
      }.freeze

      def self.client
        @client ||= new
      end

      def initialize
        @clients = {}
        VaultServer.all.each do |vault_server|
          @clients[vault_server.id] = Vault::Client.new(
            DEFAULT_CLIENT_OPTIONS.merge(
              ssl_verify: vault_server.tls_verify,
              token: vault_server.token,
              address: vault_server.address,
              ssl_cert_store: vault_server.cert_store
            )
          )
        end
      end

      # responsible servers should have the same data, so read from the first
      def read(key)
        vault = responsible_clients(key).first
        with_retries { vault.logical.read(key) }
      end

      # different servers have different keys so combine all
      def list(path)
        all = @clients.each_value.flat_map do |vault|
          with_retries { vault.logical.list(path) }
        end
        all.uniq!
        all
      end

      # write to servers that need this key
      def write(key, data)
        responsible_clients(key).each do |v|
          with_retries { v.logical.write(key, data) }
        end
      end

      # delete from all servers that hold this key
      def delete(key)
        responsible_clients(key).each do |v|
          with_retries { v.logical.delete(key) }
        end
      end

      def client(deploy_group)
        unless id = deploy_group.vault_server_id.presence
          raise "deploy group #{deploy_group.permalink} has no vault server configured"
        end
        unless client = @clients[id]
          raise "no vault server found with id #{id}"
        end
        client
      end

      private

      def with_retries(&block)
        Vault.with_retries(Vault::HTTPConnectionError, attempts: 3, &block)
      end

      # local server for deploy-group specific key and all for global key
      def responsible_clients(key)
        backend_key = key.split('/', 3).last # parse_secret_key does not know about vault namespaces

        deploy_group_permalink = SecretStorage.parse_secret_key(backend_key).fetch(:deploy_group_permalink)
        if deploy_group_permalink == 'global'
          @clients.values.presence || raise("no vault servers found")
        else
          unless deploy_group = DeployGroup.find_by_permalink(deploy_group_permalink)
            raise "no deploy group with permalink #{deploy_group_permalink} found"
          end
          [client(deploy_group)]
        end
      end
    end
  end
end
