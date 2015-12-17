module Watchers
  module Events
    class ClusterEvent

      def initialize(data)
        @data = data
      end

      def kind
        @data.object.try(:kind)
      end

      def reason
        @data.object.try(:reason)
      end

      def involved_object
        @data.object.involvedObject
      end
    end
  end
end
