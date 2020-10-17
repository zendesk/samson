# frozen_string_literal: true

# Add recursive listing which was rejected by vault-ruby see https://github.com/hashicorp/vault-ruby/pull/118
# using a monkey patch so `vault_action :list_recursive` works in the backend
module Samson
  module Secrets
    module Shared
      module ListRecursive
        # Limit scope to parent after subclass call
        #
        # Needed because wrappers including this module override methods `list` and `list_recursive` to provide a
        # unified interface within Samson. When `list_recursive` is called from a wrapper, super() is then called which
        # calls `list` and `list_recursive` multiple times when reading secrets. We want those calls to be to the
        # methods defined in the parent, so we use aliasing here to limit scope to the parent once `list_recursive` is
        # called from the wrapper.
        def self.prepended(base)
          base.alias_method :original_list, :list
          base.alias_method :original_list_recursive, :list_recursive
        end

        def list_recursive(path, root = true) # rubocop:disable Style/OptionalBooleanParameter
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
      end
    end
  end
end
