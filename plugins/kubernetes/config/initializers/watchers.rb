require 'celluloid/current'
require 'logger'
require 'kubeclient'

module Kubeclient
  class Client
    NEW_ENTITY_TYPES = %w(Deployment).map do |et|
      clazz = Class.new(RecursiveOpenStruct) do
        def initialize(hash = nil, args = {})
          args.merge!(recurse_over_arrays: true)
          super(hash, args)
        end
      end
      [Kubeclient.const_set(et, clazz), et]
    end
    ClientMixin.define_entity_methods(NEW_ENTITY_TYPES)
    ENTITY_TYPES.concat NEW_ENTITY_TYPES
  end
end

Celluloid.logger = Rails.logger
$CELLULOID_DEBUG = true

if ENV['SERVER_MODE'] && !ENV['PRECOMPILE'] && !ENV['KUBERNETES_NOT_WATCHING']
  Kubernetes::Cluster.find_each(&:watch!)
end
