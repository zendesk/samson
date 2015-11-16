module Watchers
  module Events
    class Pod
      def initialize(event)
        @event = event
      end

      def ready?
        @event.object.status.phase == 'Running' &&
          @event.object.status.conditions.present? &&
          @event.object.status.conditions.select { |c| c['type'] == 'Ready' }.all? { |c| c['status'] == 'True' }
      end

      def deleted?
        @event.type == 'DELETED'
      end

      def valid?
        @event.object.present? && @event.object.kind == 'Pod'
      end

      def name
        @event.object.metadata.name
      end
    end
  end
end
