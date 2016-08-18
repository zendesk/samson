# frozen_string_literal: true
require 'attr_encrypted'

module Samson
  module Secrets
    class DbBackend
      class Secret < ActiveRecord::Base
        self.table_name = :secrets
        self.primary_key = :id # uses a string id

        ENCRYPTION_KEY = Rails.application.secrets.secret_key_base

        attr_encrypted :value, key: ENCRYPTION_KEY, algorithm: 'aes-256-cbc'

        before_validation :store_encryption_key_sha
        validates :id, :encrypted_value, :encryption_key_sha, presence: true
        validates :id, format: %r{\A([^/\s]+/){3}[^\s]+\Z}

        private

        def store_encryption_key_sha
          self.encryption_key_sha = Digest::SHA2.hexdigest(ENCRYPTION_KEY)
        end
      end

      class << self
        def read(key)
          return unless secret = Secret.find_by_id(key)
          secret_to_hash secret
        end

        def read_multi(keys)
          secrets = Secret.where(id: keys).all
          secrets.each_with_object({}) { |s, a| a[s.id] = secret_to_hash(s) }
        end

        def write(key, data)
          secret = Secret.where(id: key).first_or_initialize
          secret.value = data.fetch(:value)
          secret.visible = data.fetch(:visible)
          secret.comment = data.fetch(:comment)
          secret.updater_id = data.fetch(:user_id)
          secret.creator_id ||= data.fetch(:user_id)
          secret.save
        end

        def delete(key)
          Secret.delete(key)
        end

        def keys
          Secret.order(:id).pluck(:id)
        end

        private

        def secret_to_hash(secret)
          {
            key: secret.id,
            value: secret.value,
            visible: secret.visible,
            comment: secret.comment,
            updater_id: secret.updater_id,
            creator_id: secret.creator_id,
            updated_at: secret.updated_at,
            created_at: secret.created_at
          }
        end
      end
    end
  end
end
