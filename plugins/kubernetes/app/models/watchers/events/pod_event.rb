module Watchers
  module Events
    class PodEvent
      def initialize(event)
        @event = event
        @api_pod = Kubernetes::Api::Pod.new(event.object)
      end

      def ready?
        @api_pod.ready?
      end

      def deleted?
        @event.type == 'DELETED'
      end

      def valid?
        @event.object.present? && @event.object.kind == 'Pod'
      end

      def name
        @api_pod.name
      end
    end
  end
end
