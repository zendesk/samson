# frozen_string_literal: true

require 'vault'

# Add recursive listing which was rejected by vault-ruby see https://github.com/hashicorp/vault-ruby/pull/118
# using a monkey patch so `vault_action :list_recursive` works in the backend
Vault::Logical::Versioned.class_eval do
  def list_recursive(mount, path, root = true)
    keys = original_list(mount, path).flat_map do |p|
      full = +"#{path}#{p}"
      if full.end_with?("/")
        original_list_recursive(mount, full, false)
      else
        full
      end
    end
    keys.each { |k| k.slice!(0, path.size) } if root
    keys
  end

  # Limit scope to logical after subclass call
  alias_method :original_list, :list
  alias_method :original_list_recursive, :list_recursive
end

module Samson
  module Secrets
    class VaultVersionedLogicalWrapper < Vault::Logical::Versioned
      def list
        super(VaultClientWrapper::MOUNT, prefix_id(''))
      end

      def read(id)
        super(VaultClientWrapper::MOUNT, prefix_id(id))
      end

      def write(id, data = {})
        super(VaultClientWrapper::MOUNT, prefix_id(id), data)
      end

      def delete(id)
        super(VaultClientWrapper::MOUNT, prefix_id(id))
      end

      def list_recursive
        super(VaultClientWrapper::MOUNT, prefix_id(''))
      end

      private

      def prefix_id(id)
        "#{VaultClientWrapper::PREFIX}/#{id}"
      end
    end
  end
end
