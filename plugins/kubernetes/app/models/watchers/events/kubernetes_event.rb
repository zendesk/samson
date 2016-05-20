module Watchers
  module Events
    class KubernetesEvent
      def initialize(data)
        @data = data
      end

      def kind
        @data.object.try(:kind)
      end
    end
  end
end
