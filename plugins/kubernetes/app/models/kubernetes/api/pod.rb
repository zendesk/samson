module Kubernetes
  module Api
    class Pod
      def initialize(api_pod)
        @pod = api_pod
      end

      def ready?
        @pod.status.phase == 'Running' && condition_ready?
      end

      def name
        @pod.metadata.name
      end

      private

      def condition_ready?
        if @pod.status.conditions.present?
          ready = @pod.status.conditions.find { |c| c['type'] == 'Ready' }
          ready && ready['status'] == 'True'
        else
          false
        end
      end
    end
  end
end
