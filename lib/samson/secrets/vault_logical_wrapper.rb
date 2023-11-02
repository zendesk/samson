# frozen_string_literal: true

require 'vault'
require_relative 'shared/list_recursive'

Vault::Logical.prepend(Samson::Secrets::Shared::ListRecursive)

module Samson
  module Secrets
    class VaultLogicalWrapper < Vault::Logical
      def list
        super(full_path(''))
      end

      def read(id)
        super(full_path(id))
      end

      def write(id, data = {})
        super(full_path(id), data)
      end

      def delete(id)fe
        super(full_path(id))
      end

      def list_recursive(path = '')
        super(full_path(path))
      end

      private

      def full_path(id)
        "#{Samson::Secrets::VaultClientManager::MOUNT}/#{Samson::Secrets::VaultClientManager::PREFIX}/#{id}"
      end
    end
  end
end
