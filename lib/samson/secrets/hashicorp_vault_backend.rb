# frozen_string_literal: true

module Samson
  module Secrets
    class HashicorpVaultBackend
      VAULT_SECRET_BACKEND = 'secret/'
      SAMSON_SECRET_NAMESPACE = 'apps/'
      # we don't really want other directories in the key,
      # and there may be other chars that we find we don't like
      ENCODINGS = {"/": "%2F"}.freeze

      class << self
        def read(key)
          key = vault_path(key)
          result = vault_client.read(key)
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
          vault_client.write(
            vault_path(key),
            vault: data.fetch(:value),
            visible: data.fetch(:visible),
            comment: data.fetch(:comment),
            creator_id: data.fetch(:user_id)
          )
        end

        def delete(key)
          vault_client.delete(vault_path(key))
        end

        def keys
          keys = vault_client.list(VAULT_SECRET_BACKEND + SAMSON_SECRET_NAMESPACE)
          keys = keys_recursive(keys)
          keys.uniq! # we read from multiple backends that might have the same keys
          keys.map! do |secret_path|
            convert_path(secret_path, :decode) # FIXME: ideally only decode the key(#4) part
          end
        end

        private

        # get and cache a copy of the client that has a token
        def vault_client
          @vault_client ||= VaultClient.new
        end

        def keys_recursive(keys, key_path = "")
          keys.flat_map do |key|
            new_key = key_path + key
            if key.end_with?('/') # a directory
              keys_recursive(vault_client.list(VAULT_SECRET_BACKEND + SAMSON_SECRET_NAMESPACE + new_key), new_key)
            else
              new_key
            end
          end
        end

        # key is the last element and should not include bad characters
        def vault_path(key)
          parts = key.split(SecretStorage::SEPARATOR, SecretStorage::SECRET_KEYS_PARTS.size)
          parts[-1] = convert_path(parts[-1], :encode)
          VAULT_SECRET_BACKEND + SAMSON_SECRET_NAMESPACE + parts.join(SecretStorage::SEPARATOR)
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
