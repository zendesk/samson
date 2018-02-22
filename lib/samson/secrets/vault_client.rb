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
      def read(id)
        vault = responsible_clients(id).first
        with_retries { vault.logical.read(wrap_id(id)) }
      end

      # different servers have different ids so combine all
      def list_recursive(path)
        path = wrap_id(path)
        all = Samson::Parallelizer.map(clients.values) do |vault|
          begin
            with_retries { vault.logical.list_recursive(path) }
          rescue
            Airbrake.notify($!, error_message: "Error talking to vault server #{vault.address} during list_recursive")
            []
          end
        end.flatten(1)
        all.uniq!
        all
      end

      # write to servers that need this id
      def write(id, data)
        Samson::Parallelizer.map(responsible_clients(id)) do |v|
          with_retries { v.logical.write(wrap_id(id), data) }
        end
      end

      # delete from all servers that hold this id
      def delete(id, all: false)
        selected_clients = (all ? clients.values : responsible_clients(id))
        Samson::Parallelizer.map(selected_clients) do |v|
          with_retries { v.logical.delete(wrap_id(id)) }
        end
      end

      def expire_clients
        @clients = nil
        @client_map = nil
      end

      # called via cron job to renew the current token
      def renew_token
        clients.each do |id, client|
          begin
            with_retries { client.auth_token.renew_self }
          rescue
            Airbrake.notify($!, vault_server_id: id)
          end
        end
      end

      def client(deploy_group_permalink)
        unless client_map[:deploy_groups].key?(deploy_group_permalink)
          raise "no deploy group with permalink #{deploy_group_permalink} found"
        end
        unless id = client_map[:deploy_groups][deploy_group_permalink]
          raise VaultServerNotConfigured, "deploy group #{deploy_group_permalink} has no vault server configured"
        end
        unless client = clients[id]
          raise "no vault server found with id #{id}"
        end
        client
      end

      private

      def wrap_id(id)
        "#{VaultServer::PREFIX}#{id}"
      end

      def with_retries(&block)
        Vault.with_retries(Vault::HTTPConnectionError, attempts: 3, &block)
      end

      # - local server for deploy-group specific id
      # - servers in environment for environment specific id
      # - all for global id
      def responsible_clients(id)
        parts = Samson::Secrets::Manager.parse_id(id)
        deploy_group_permalink = parts.fetch(:deploy_group_permalink)
        environment_permalink = parts.fetch(:environment_permalink)

        if deploy_group_permalink == 'global'
          if environment_permalink == 'global'
            clients.values
          else
            unless deploy_group_permalinks = client_map[:environments][environment_permalink]
              raise "no environment with permalink #{environment_permalink} found"
            end
            deploy_group_permalinks.map { |p| client(p) }.uniq
          end
        else
          [client(deploy_group_permalink)]
        end.presence || raise("no vault servers found for #{id}")
      end

      def clients
        @clients ||= VaultServer.all.each_with_object({}) do |vault_server, all|
          all[vault_server.id] = vault_server.client
        end
      end

      def client_map
        @client_map ||= ActiveSupport::Cache::MemoryStore.new
        @client_map.fetch :map, expires_in: 1.minute, race_condition_ttl: 10.seconds do
          {
            deploy_groups: DeployGroup.pluck(:permalink, :vault_server_id).to_h,
            environments: Environment.all.map do |e|
              [e.permalink, e.deploy_groups.select(&:vault_server_id).map(&:permalink)]
            end.to_h,
          }
        end
      end
    end
  end
end
