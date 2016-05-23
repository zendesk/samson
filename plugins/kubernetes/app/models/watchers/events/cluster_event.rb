module Watchers
  module Events
    class ClusterEvent < KubernetesEvent
      def reason
        @data.object.try(:reason)
      end

      def involved_object
        @data.object.involvedObject
      end
    end
  end
end
