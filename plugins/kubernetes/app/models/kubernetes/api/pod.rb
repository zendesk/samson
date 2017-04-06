# frozen_string_literal: true
module Kubernetes
  module Api
    class Pod
      def initialize(api_pod, client: nil)
        @pod = api_pod
        @client = client
      end

      def name
        @pod.metadata.name
      end

      def namespace
        @pod.metadata.namespace
      end

      def live?
        completed? || (phase == 'Running' && ready?)
      end

      def completed?
        phase == 'Succeeded'
      end

      def failed?
        phase == 'Failed'
      end

      def restarted?
        @pod.status.containerStatuses.try(:any?) { |s| s.restartCount.positive? }
      end

      def phase
        @pod.status.phase
      end

      def reason
        reasons = []
        reasons.concat @pod.status.conditions.try(:map, &:reason).to_a
        reasons.concat @pod.status.containerStatuses.
          try(:map) { |s| s.to_h.fetch(:state).values.map { |s| s[:reason] } }.
          to_a
        reasons.reject(&:blank?).uniq.join("/").presence || "Unknown"
      end

      def deploy_group_id
        labels.deploy_group_id.to_i
      end

      def role_id
        labels.role_id.to_i
      end

      def containers
        @pod.spec.containers.map(&:to_h)
      end

      # tries to get logs from current or previous pod depending on if it restarted
      def logs(container)
        fetch_logs(container, previous: restarted?)
      rescue KubeException # not found or pod is initializing
        begin
          fetch_logs(container, previous: !restarted?)
        rescue KubeException
          nil
        end
      end

      def events_indicate_failure?
        bad = events.reject { |e| e.type == 'Normal' }
        readiness_failures, other_failures = bad.partition do |e|
          e.reason == "Unhealthy" && e.message =~ /\A\S+ness probe failed/
        end
        other_failures.any? || readiness_failures.any? { |event| probe_failed_to_often?(event) }
      end

      def events
        @events ||= @client.get_events(
          namespace: namespace,
          field_selector: "involvedObject.name=#{name}"
        ).select do |event|
          # compare strings to avoid parsing time '2017-03-31T22:56:20Z'
          event.metadata.creationTimestamp >= @pod.status.startTime.to_s
        end
      end

      def init_containers
        return [] unless containers = @pod.dig(:metadata, :annotations, :'pod.alpha.kubernetes.io/init-containers')
        JSON.parse(containers, symbolize_names: true)
      end

      private

      # if the pod is still running we stream the logs until it times out to get as much info as possible
      # necessary since logs often hang for a while even if the pod is already done
      def fetch_logs(container, previous:)
        if previous
          @client.get_pod_log(name, namespace, container: container, previous: true)
        else
          result = "".dup
          begin
            timeout_logs do
              @client.watch_pod_log(name, namespace, container: container).each do |log|
                result << log << "\n"
              end
            end
          rescue Timeout::Error
            result << "... log streaming timeout"
          end
          result
        end
      end

      # easy stub
      def timeout_logs(&block)
        Timeout.timeout(Integer(ENV['KUBERNETES_LOG_TIMEOUT'] || '20'), &block)
      end

      def probe_failed_to_often?(event)
        probe =
          case event.message
          when /\AReadiness/ then :readinessProbe
          when /\ALiveliness/ then :livelinessProbe
          else raise("Unknown probe #{event.message}")
          end
        event.count >= failure_threshold(probe)
      end

      # per http://kubernetes.io/docs/api-reference/v1/definitions/ default is 3
      # by default checks every 10s so that gives us 30s to pass
      def failure_threshold(probe)
        @pod.dig(:spec, :containers, 0, probe, :failureThreshold) || 3
      end

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
