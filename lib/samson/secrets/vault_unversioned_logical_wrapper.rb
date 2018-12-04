# frozen_string_literal: true

require 'vault'

# Add recursive listing which was rejected by vault-ruby see https://github.com/hashicorp/vault-ruby/pull/118
# using a monkey patch so `vault_action :list_recursive` works in the backend
Vault::Logical::Unversioned.class_eval do
  def list_recursive(path, root = true)
    keys = original_list(path).flat_map do |p|
      full = +"#{path}#{p}"
      if full.end_with?("/")
        original_list_recursive(full, false)
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
    class VaultUnversionedLogicalWrapper < Vault::Logical::Unversioned
      def list
        super(full_path(''))
      end

      def read(id)
        super(full_path(id))
      end

      def write(id, data = {})
        super(full_path(id), data)
      end

      def delete(id)
        super(full_path(id))
      end

      def list_recursive
        super(full_path(''))
      end

      private

      def full_path(id)
        "#{VaultClientWrapper::MOUNT}/#{VaultClientWrapper::PREFIX}/#{id}"
      end
    end
  end
end
