# frozen_string_literal: true

require 'vault'
require_relative 'shared/list_recursive'

Vault::KV.prepend(Samson::Secrets::Shared::ListRecursive)

module Samson
  module Secrets
    class VaultKvWrapper < Vault::KV
      def list
        super(prefix_id(''))
      end

      def read(id, *args)
        super(prefix_id(id), *args)
      end

      def read_metadata(id)
        super(prefix_id(id))
      end

      def write(id, data = {})
        super(prefix_id(id), data)
      end

      def delete(id)
        super(prefix_id(id))
      end

      def list_recursive(path = '')
        super(prefix_id(path))
      end

      private

      def prefix_id(id)
        "#{Samson::Secrets::VaultClientManager::PREFIX}/#{id}"
      end
    end
  end
end
