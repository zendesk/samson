# frozen_string_literal: true

require 'vault'

module Samson
  module Secrets
    class VaultClientWrapper < Vault::Client
      # TODO: make these configurable via env vars and send env vars to samson_secret_puller
      MOUNT = 'secret'
      PREFIX = 'apps'

      def initialize(versioned_kv:, **client_args)
        @versioned_kv = versioned_kv

        super client_args
      end

      def logical
        @logical ||= @versioned_kv ? VaultVersionedLogicalWrapper.new(self) : VaultUnversionedLogicalWrapper.new(self)
      end
    end
  end
end
