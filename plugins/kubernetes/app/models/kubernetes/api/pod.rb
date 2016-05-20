module Kubernetes
  module Api
    class Pod
      def initialize(api_pod)
        @pod = api_pod
      end

      def name
        @pod.metadata.name
      end

      def valid?
        @pod.metadata.labels.present? && @pod.metadata.labels.project_id.present?
      end

      def live?
        phase == 'Running' && ready?
      end

      def restarted?
        @pod.status.containerStatuses.try(:any?) { |s| s.restartCount != 0 }
      end

      def phase
        @pod.status.phase
      end

      def project_id
        labels.project_id.to_i
      end

      def release_id
        labels.release_id.to_i
      end

      def deploy_group_id
        labels.deploy_group_id.to_i
      end

      def role_id
        labels.role_id.to_i
      end

      def rc_unique_identifier
        @pod.metadata.labels.rc_unique_identifier
      end

      private

      def labels
        @pod.metadata.try(:labels)
      end

      def ready?
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
