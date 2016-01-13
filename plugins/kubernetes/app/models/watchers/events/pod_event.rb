module Watchers
  module Events
    class PodEvent < KubernetesEvent
      attr_reader :pod

      def initialize(data)
        super(data)
        @pod = Kubernetes::Api::Pod.new(data.object)
      end

      def deleted?
        @data.type == 'DELETED'
      end

      def valid?
        @data.object.present? && @data.object.kind == 'Pod'
      end
    end
  end
end
