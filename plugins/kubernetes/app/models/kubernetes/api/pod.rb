module Kubernetes
  module Api
    class Pod
      def initialize(api_pod)
        @api_pod = api_pod
      end

      def ready?
        @api_pod.status.phase == 'Running' && condition_ready?
      end

      def name
        @api_pod.metadata.name
      end

      private

      def condition_ready?
        @api_pod.status.conditions.present? &&
            @api_pod.status.conditions
                .select { |c| c['type'] == 'Ready' }
                .all? { |c| c['status'] == 'True' }
      end
    end
  end
end
