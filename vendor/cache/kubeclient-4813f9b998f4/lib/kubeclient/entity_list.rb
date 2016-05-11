require 'delegate'
module Kubeclient
  module Common
    # Kubernetes Entity List
    class EntityList < DelegateClass(Array)
      attr_reader :kind, :resourceVersion

      def initialize(kind, resource_version, list)
        @kind = kind
        # rubocop:disable Style/VariableName
        @resourceVersion = resource_version
        super(list)
      end
    end
  end
end
