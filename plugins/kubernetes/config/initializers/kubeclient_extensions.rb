require 'kubeclient'

module Kubeclient
  class Client
    # Add Deployment and Daemonset waiting for PR:
    # https://github.com/abonas/kubeclient/pull/143
    NEW_ENTITY_TYPES = %w[Deployment DaemonSet Job].map do |et|
      clazz = Class.new(RecursiveOpenStruct) do
        def initialize(hash = nil, args = {})
          args[:recurse_over_arrays] = true
          super(hash, args)
        end
      end
      [Kubeclient.const_set(et, clazz), et]
    end
    ClientMixin.define_entity_methods(NEW_ENTITY_TYPES)
    ENTITY_TYPES.concat NEW_ENTITY_TYPES
  end
end
