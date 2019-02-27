# frozen_string_literal: true
module Kubernetes
  module Api
    class Pod
      INIT_CONTAINER_KEY = :'pod.beta.kubernetes.io/init-containers'
      INGORED_AUTOSCALE_EVENT_REASONS = %w[FailedGetMetrics FailedRescale].freeze

      def self.init_containers(pod)
        containers = pod.dig(:spec, :initContainers) || []
        if json = pod.dig(:metadata, :annotations, Kubernetes::Api::Pod::INIT_CONTAINER_KEY)
          containers += JSON.parse(json, symbolize_names: true)
        end
        containers
      end

      def initialize(api_pod, client: nil)
        @pod = api_pod
        @client = client
      end

      def name
        @pod.dig(:metadata, :name)
      end

      def namespace
        @pod.dig(:metadata, :namespace)
      end

      def annotations
        @pod[:metadata][:annotations] ||= {}
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
        @pod.dig(:status, :containerStatuses)&.any? { |s| s.fetch(:restartCount) > 0 }
      end

      def phase
        @pod.dig(:status, :phase)
      end

      def reason
        reasons = []
        reasons.concat @pod.dig(:status, :conditions)&.map { |c| c[:reason] }.to_a
        reasons.concat @pod.dig(:status, :containerStatuses)&.
          map { |s| s.fetch(:state).values.map { |s| s[:reason] } }.
          to_a
        reasons.reject(&:blank?).uniq.join("/").presence || "Unknown"
      end

      def deploy_group_id
        Integer(labels.fetch(:deploy_group_id))
      end

      def role_id
        Integer(labels.fetch(:role_id))
      end

      def containers
        @pod.dig(:spec, :containers)
      end

      # tries to get logs from current or previous pod depending on if it restarted
      def logs(container, end_time)
        fetch_logs(container, end_time, previous: restarted?)
      rescue *SamsonKubernetes.connection_errors # not found or pod is initializing
        begin
          fetch_logs(container, end_time, previous: !restarted?)
        rescue *SamsonKubernetes.connection_errors
          nil
        end
      end

      def events_indicate_failure?
        events_indicating_failure.any?
      end

      def waiting_for_resources?
        events = events_indicating_failure
        events.any? && events_indicating_failure.all? { |e| e[:reason] == "FailedScheduling" }
      end

      def events
        @events ||= raw_events.select do |event|
          # compare strings to avoid parsing time '2017-03-31T22:56:20Z'
          event.dig(:metadata, :creationTimestamp) >= @pod.dig(:status, :startTime).to_s
        end
      end

      def init_containers
        self.class.init_containers(@pod)
      end

      private

      def events_indicating_failure
        @events_indicating_failure ||= begin
          bad = events.dup
          bad.reject! { |e| e.fetch(:type) == 'Normal' }
          bad.reject! { |e| ignorable_hpa_event?(e) }
          bad.reject! do |e|
            e[:reason] == "Unhealthy" && e[:message] =~ /\A\S+ness probe failed/ && !probe_failed_to_often?(e)
          end
          bad
        end
      end

      def ignorable_hpa_event?(event)
        event[:kind] == 'HorizontalPodAutoscaler' && INGORED_AUTOSCALE_EVENT_REASONS.include?(event[:reason])
      end

      def raw_events
        SamsonKubernetes.retry_on_connection_errors do
          @client.get_events(
            namespace: namespace,
            field_selector: "involvedObject.name=#{name}"
          ).fetch(:items)
        end
      end

      # if the pod is still running we stream the logs until it times out to get as much info as possible
      # necessary since logs often hang for a while even if the pod is already done
      def fetch_logs(container, end_time, previous:)
        if previous
          SamsonKubernetes.retry_on_connection_errors do
            tries = 3
            tries.times do |i|
              logs = @client.get_pod_log(name, namespace, container: container, previous: true)

              # sometimes the previous containers logs are not yet available, so we have to wait a bit
              return logs if i + 1 == tries || !logs.start_with?("Unable to retrieve container logs")
              Rails.logger.error("Unable to find logs, retrying")
              sleep 1
            end
          end
        else
          wait = end_time - Time.now
          if wait < 2 # timeout almost over or over, so just fetch logs
            SamsonKubernetes.retry_on_connection_errors do
              @client.get_pod_log(name, namespace, container: container)
            end
          else
            # still waiting, stream logs
            result = +""
            begin
              timeout_logs(wait) do
                SamsonKubernetes.retry_on_connection_errors do
                  @client.watch_pod_log(name, namespace, container: container).each do |log|
                    result << log << "\n"
                  end
                end
              end
            rescue Timeout::Error
              result << "... log streaming timeout"
            end
            result
          end
        end
      end

      # easy to stub
      def timeout_logs(timeout, &block)
        Timeout.timeout(timeout, &block)
      end

      def probe_failed_to_often?(event)
        probe =
          case event[:message]
          when /\AReadiness/ then :readinessProbe
          when /\ALiveness/ then :livenessProbe
          else raise("Unknown probe #{event[:message]}")
          end
        event[:count] >= failure_threshold(probe)
      end

      # per http://kubernetes.io/docs/api-reference/v1/definitions/ default is 3
      # by default checks every 10s so that gives us 30s to pass
      def failure_threshold(probe)
        @pod.dig(:spec, :containers, 0, probe, :failureThreshold) || 3
      end

      def labels
        @pod.dig(:metadata, :labels)
      end

      def ready?
        @pod.dig(:status, :conditions)&.detect { |c| c[:type] == 'Ready' && c[:status] == 'True' }
      end
    end
  end
end
