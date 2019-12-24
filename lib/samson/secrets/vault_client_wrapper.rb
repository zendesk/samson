# frozen_string_literal: true

require 'vault'

module Samson
  module Secrets
    class VaultClientWrapper < Vault::Client
      attr_reader :versioned_kv

      def initialize(versioned_kv:, **client_args)
        @versioned_kv = versioned_kv

        super client_args
      end

      # Overwrite Vault::Client#kv to provide unified interface for interacting with KeyValue store
      # Could remove if this is implemented: https://github.com/hashicorp/vault-ruby/pull/194#issuecomment-448448359
      def kv
        if @versioned_kv
          @kv ||= VaultKvWrapper.new(self, Samson::Secrets::VaultClientManager::MOUNT)
        else
          @logical ||= VaultLogicalWrapper.new(self)
        end
      end
    end
  end
end
