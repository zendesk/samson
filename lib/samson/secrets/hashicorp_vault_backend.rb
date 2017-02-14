# frozen_string_literal: true
require 'vault'

module Samson
  module Secrets
    class BackendError < StandardError
    end

    class HashicorpVaultBackend
      # we don't really want other directories in the key,
      # and there may be other chars that we find we don't like
      ENCODINGS = {"/": "%2F"}.freeze

      class << self
        def read(key)
          return unless key
          result = vault_action(:read, vault_path(key))
          return if !result || result.data[:vault].nil?

          result = result.to_h
          result = result.merge(result.delete(:data))
          result[:value] = result.delete(:vault)
          result
        end

        def read_multi(keys)
          keys.each_with_object({}) do |key, a|
            begin
              if value = read(key)
                a[key] = value
              end
            rescue VaultClient::VaultServerNotConfigured # deploy group has no vault server
              nil
            end
          end
        end

        def write(key, data)
          user_id = data.fetch(:user_id)
          current = read(key)
          creator_id = (current && current[:creator_id]) || user_id

          vault_action(
            :write,
            vault_path(key),
            vault: data.fetch(:value),
            visible: data.fetch(:visible),
            comment: data.fetch(:comment),
            creator_id: creator_id,
            updater_id: user_id
          )
        end

        def delete(key)
          vault_action(:delete, vault_path(key))
        end

        def keys
          keys = vault_action(:list_recursive, "")
          keys.uniq! # we read from multiple backends that might have the same keys
          keys.map! { |secret_path| vault_path(secret_path, :decode) }
        end

        private

        def vault_action(method, path, *args)
          vault_client.public_send(method, path, *args)
        rescue Vault::HTTPConnectionError => e
          raise Samson::Secrets::BackendError, "Error talking to vault backend: #{e.message}"
        end

        def vault_client
          Samson::Secrets::VaultClient.client
        end

        # key is the last element and should not include bad characters
        # ... could be faster by not jumping through hash generation and parsing
        def vault_path(key, direction = :encode)
          parts = SecretStorage.parse_secret_key(key)
          raise ActiveRecord::RecordNotFound, "Invalid key #{key.inspect}" unless parts[:key]
          parts[:key] = convert_path(parts[:key], direction)
          SecretStorage.generate_secret_key(parts)
        end

        # convert from/to escaped characters
        def convert_path(string, direction)
          string = string.dup
          if direction == :decode
            ENCODINGS.each { |k, v| string.gsub!(v.to_s, k.to_s) }
          elsif direction == :encode
            ENCODINGS.each { |k, v| string.gsub!(k.to_s, v.to_s) }
          else
            raise ArgumentError, "direction is required"
          end
          string
        end
      end
    end
  end
end
