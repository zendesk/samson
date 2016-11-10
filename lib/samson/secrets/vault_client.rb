# frozen_string_literal: true

module Samson
  module Secrets
    # Vault wrapper that sends requests to all matching vault servers
    class VaultClient
      def self.client
        @client ||= new
      end

      # responsible servers should have the same data, so read from the first
      def read(key)
        vault = responsible_clients(key).first
        with_retries { vault.logical.read(wrap_key(key)) }
      end

      # different servers have different keys so combine all
      def list_recursive(path)
        path = wrap_key(path)
        all = clients.each_value.flat_map do |vault|
          with_retries { vault.logical.list_recursive(path) }
        end
        all.uniq!
        all
      end

      # write to servers that need this key
      def write(key, data)
        responsible_clients(key).each do |v|
          with_retries { v.logical.write(wrap_key(key), data) }
        end
      end

      # delete from all servers that hold this key
      def delete(key)
        responsible_clients(key).each do |v|
          with_retries { v.logical.delete(wrap_key(key)) }
        end
      end

      def client(deploy_group)
        unless id = deploy_group.vault_server_id.presence
          raise "deploy group #{deploy_group.permalink} has no vault server configured"
        end
        unless client = clients[id]
          raise "no vault server found with id #{id}"
        end
        client
      end

      def refresh_clients
        @clients = nil
      end

      private

      def wrap_key(key)
        "#{VaultServer::PREFIX}#{key}"
      end

      def with_retries(&block)
        Vault.with_retries(Vault::HTTPConnectionError, attempts: 3, &block)
      end

      # local server for deploy-group specific key and all for global key
      def responsible_clients(key)
        deploy_group_permalink = SecretStorage.parse_secret_key(key).fetch(:deploy_group_permalink)
        if deploy_group_permalink == 'global'
          clients.values.presence || raise("no vault servers found")
        else
          unless deploy_group = DeployGroup.find_by_permalink(deploy_group_permalink)
            raise "no deploy group with permalink #{deploy_group_permalink} found"
          end
          [client(deploy_group)]
        end
      end

      def clients
        @clients ||= VaultServer.all.each_with_object({}) do |vault_server, all|
          all[vault_server.id] = vault_server.client
        end
      end
    end
  end
end
