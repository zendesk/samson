module Watchers
  module Events
    class Pod
      def initialize(event)
        @event = event
      end

      def ready?
        @event.object.status.phase == 'Running' && condition_ready?
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

      private

      def condition_ready?
        @event.object.status.conditions.present? &&
          @event.object.status.conditions
            .select { |c| c['type'] == 'Ready' }
            .all? { |c| c['status'] == 'True' }
      end
    end
  end
end
