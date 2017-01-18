# frozen_string_literal: true

module Samson
  module Secrets
    # Vault wrapper that sends requests to all matching vault servers
    class VaultClient
      class VaultServerNotConfigured < StandardError
      end

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
        all = parallel_map(clients.values) do |vault|
          with_retries { vault.logical.list_recursive(path) }
        end
        all.uniq!
        all
      end

      # write to servers that need this key
      def write(key, data)
        parallel_map(responsible_clients(key)) do |v|
          with_retries { v.logical.write(wrap_key(key), data) }
        end
      end

      # delete from all servers that hold this key
      def delete(key)
        parallel_map(responsible_clients(key)) do |v|
          with_retries { v.logical.delete(wrap_key(key)) }
        end
      end

      def client(deploy_group)
        unless id = deploy_group.vault_server_id
          raise VaultServerNotConfigured, "deploy group #{deploy_group.permalink} has no vault server configured"
        end
        unless client = clients[id]
          raise "no vault server found with id #{id}"
        end
        client
      end

      def refresh_clients
        @clients = nil
      end

      # called via cron job to renew the current token
      def renew_token
        clients.each_value { |c| with_retries { c.auth_token.renew_self } }
      end

      private

      def parallel_map(elements)
        elements.map { |element| Thread.new { yield element } }.map(&:value).flatten(1)
      end

      def wrap_key(key)
        "#{VaultServer::PREFIX}#{key}"
      end

      def with_retries(&block)
        Vault.with_retries(Vault::HTTPConnectionError, attempts: 3, &block)
      end

      # - local server for deploy-group specific key
      # - servers in environment for environment specific key
      # - all for global key
      def responsible_clients(key)
        parts = SecretStorage.parse_secret_key(key)
        deploy_group_permalink = parts.fetch(:deploy_group_permalink)
        environment_permalink = parts.fetch(:environment_permalink)

        if deploy_group_permalink == 'global'
          if environment_permalink == 'global'
            clients.values
          else
            unless environment = Environment.find_by_permalink(environment_permalink)
              raise "no environment with permalink #{environment_permalink} found"
            end
            environment.deploy_groups.select(&:vault_server_id).map { |deploy_group| client(deploy_group) }.uniq
          end
        else
          unless deploy_group = DeployGroup.find_by_permalink(deploy_group_permalink)
            raise "no deploy group with permalink #{deploy_group_permalink} found"
          end
          [client(deploy_group)]
        end.presence || raise("no vault servers found for #{key}")
      end

      def clients
        @clients ||= VaultServer.all.each_with_object({}) do |vault_server, all|
          all[vault_server.id] = vault_server.client
        end
      end
    end
  end
end
