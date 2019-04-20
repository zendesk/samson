# frozen_string_literal: true
require 'vault'

module Samson
  module Secrets
    class BackendError < StandardError
    end

    class HashicorpVaultBackend
      # / means diretory in vault and we want to keep all the ids in the same folder
      DIRECTORY_SEPARATOR = "/"
      ID_SEGMENTS = 4
      IMPORTANT_COLUMNS = [:visible, :deprecated_at, :comment, :creator_id, :updater_id].freeze

      class << self
        def read(id, *args)
          return unless id
          result = vault_action(:read, vault_path(id, :encode), *args)
          return if !result || result.data[:vault].nil?

          result = result.to_h
          result = result.merge(result.delete(:data))
          result[:value] = result.delete(:vault)
          result
        end

        # history with full versions
        # see https://www.vaultproject.io/api/secret/kv/kv-v2.html#read-secret-metadata
        def history(id, resolve: false)
          return unless history = vault_action(:read_metadata, vault_path(id, :encode))
          return history unless resolve
          history.fetch(:versions).each do |version, metadata|
            metadata.replace(metadata: metadata.dup)
            next if metadata.dig(:metadata, :destroyed)
            metadata.merge!(read(id, version))
          end
          history
        end

        def read_multi(ids)
          # will be used inside the threads and can lead to errors when not preloaded
          # reproducible by running a single test like hashicorp_vault_backend_test.rb -n '/filter_keys_by_value/'
          Samson::Secrets::Manager.name

          found = {}
          Samson::Parallelizer.map(ids, db: true) do |id|
            begin
              if value = read(id)
                found[id] = value
              end
            rescue # deploy group has no vault server or deploy group no longer exists
              nil
            end
          end
          found
        end

        def write(id, data)
          user_id = data.fetch(:user_id)
          current = read(id)
          creator_id = (current && current[:creator_id]) || user_id
          data = data.merge(creator_id: creator_id, updater_id: user_id)

          begin
            deep_write(id, data)
          rescue
            revert(id, current)
            raise
          end
        end

        def delete(id)
          vault_action(:delete, vault_path(id, :encode))
        end

        def ids
          ids = vault_action(:list_recursive)
          ids.uniq! # we read from multiple backends that might have the same ids
          ids.map! do |secret_path|
            begin
              vault_path(secret_path, :decode)
            rescue ActiveRecord::RecordNotFound => e
              Samson::ErrorNotifier.notify(e, notice: true)
              nil
            end
          end
          ids.compact!
          ids
        end

        def deploy_groups
          DeployGroup.where.not(vault_server_id: nil)
        end

        private

        def revert(id, current)
          if current
            deep_write(id, current)
          else
            delete(id)
          end
        rescue
          nil # ignore errors in here
        end

        # write to the backend ... but exclude metadata from a read/write update cycle
        def deep_write(id, data)
          important = {vault: data.fetch(:value)}.merge(data.slice(*IMPORTANT_COLUMNS))
          vault_action(:write, vault_path(id, :encode), important)
        end

        def vault_action(method, *args)
          vault_client_manager.public_send(method, *args)
        rescue Vault::HTTPConnectionError => e
          raise Samson::Secrets::BackendError, "Error talking to vault backend: #{e.message}"
        end

        def vault_client_manager
          Samson::Secrets::VaultClientManager.instance
        end

        # id is the last element and should not include directories
        def vault_path(id, direction)
          parts = id.split(DIRECTORY_SEPARATOR, ID_SEGMENTS)
          raise ActiveRecord::RecordNotFound, "Invalid id #{id.inspect}" unless parts.size == ID_SEGMENTS
          convert_path!(parts.last, direction)
          parts.join(DIRECTORY_SEPARATOR)
        end

        # convert from/to escaped characters
        def convert_path!(string, direction)
          case direction
          when :encode then string.gsub!(DIRECTORY_SEPARATOR, "%2F")
          when :decode then string.gsub!("%2F", DIRECTORY_SEPARATOR)
          else raise ArgumentError, "direction is required"
          end
          string
        end
      end
    end
  end
end
