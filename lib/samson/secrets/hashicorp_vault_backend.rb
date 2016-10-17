# frozen_string_literal: true

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
          result = vault_action(:read, vault_path(key))
          return if !result || result.data[:vault].nil?

          result = result.to_h
          result = result.merge(result.delete(:data))
          result[:value] = result.delete(:vault)
          result
        end

        def read_multi(keys)
          keys.each_with_object({}) do |key, a|
            if value = read(key)
              a[key] = value
            end
          end
        end

        def write(key, data)
          vault_action(
            :write,
            vault_path(key),
            vault: data.fetch(:value),
            visible: data.fetch(:visible),
            comment: data.fetch(:comment),
            creator_id: data.fetch(:user_id)
          )
        end

        def delete(key)
          vault_action(:delete, vault_path(key))
        end

        def keys
          keys = vault_action(:list, "")
          keys = keys_recursive(keys)
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

        def keys_recursive(keys, key_path = "")
          keys.flat_map do |key|
            new_key = key_path + key
            if key.end_with?('/') # a directory
              # we work with keys we got back from vault, so not encoding
              keys_recursive(vault_action(:list, new_key), new_key)
            else
              new_key
            end
          end
        end

        # key is the last element and should not include bad characters
        # ... could be faster by not jumping through hash generation and parsing
        def vault_path(key, direction = :encode)
          parts = SecretStorage.parse_secret_key(key)
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
