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
        @pod.status.conditions.present? &&
            @pod.status.conditions
                .select { |c| c['type'] == 'Ready' }
                .all? { |c| c['status'] == 'True' }
      end
    end
  end
end
