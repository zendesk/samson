module Watchers
  module Events
    class PodEvent
      attr_reader :pod

      def initialize(event)
        @event = event
        @pod = Kubernetes::Api::Pod.new(event.object)
      end

      def deleted?
        @event.type == 'DELETED'
      end

      def valid?
        @event.object.present? && @event.object.kind == 'Pod'
      end
    end
  end
end
