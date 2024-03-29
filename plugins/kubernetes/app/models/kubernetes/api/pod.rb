# frozen_string_literal: true
module Kubernetes
  module Api
    class Pod
      INIT_CONTAINER_KEY = :'pod.beta.kubernetes.io/init-containers'
      WAITING_FOR_RESOURCES = [
        "FailedScheduling",
        "FailedCreatePodSandBox",
        "FailedAttachVolume",
        "OutOfcpu",
        "OutOfmemory"
      ].freeze

      attr_writer :events

      def self.init_containers(pod)
        containers = pod.dig(:spec, :initContainers) || []
        # TODO: remove this deprecated support
        if json = pod.dig(:metadata, :annotations, Kubernetes::Api::Pod::INIT_CONTAINER_KEY)
          containers += JSON.parse(json, symbolize_names: true)
        end
        containers
      end

      def initialize(api_pod, client: nil)
        @pod = api_pod
        @client = client
      end

      def uid
        @pod.dig(:metadata, :uid)
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

      def restart_details
        statuses = (@pod.dig(:status, :containerStatuses) || []) + (@pod.dig(:status, :initContainerStatuses) || [])
        statuses.detect do |s|
          next unless s.fetch(:restartCount) > 0
          reason = s.dig(:lastState, :terminated, :reason) || s.dig(:state, :terminated, :reason) || "Unknown"
          return "Restarted (#{s[:name]} #{reason})"
        end
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

      # TODO: move into resource_status.rb
      def container_names
        (@pod.dig(:spec, :containers) + self.class.init_containers(@pod)).map { |c| c.fetch(:name) }.uniq
      end

      # tries to get logs from current or previous pod depending on if it restarted
      # TODO: move into resource_status.rb
      def logs(container, end_time)
        fetch_logs(container, end_time, previous: !!restart_details)
      rescue *SamsonKubernetes.connection_errors # not found or pod is initializing
        begin
          fetch_logs(container, end_time, previous: !restart_details)
        rescue *SamsonKubernetes.connection_errors
          nil
        end
      end

      def events_indicate_failure?
        events_indicating_failure.any?
      end

      def waiting_for_resources?
        events = events_indicating_failure
        events.any? && events_indicating_failure.all? { |e| WAITING_FOR_RESOURCES.include?(e[:reason]) }
      end

      private

      def events_indicating_failure
        @events_indicating_failure ||= begin
          bad = @events.dup
          bad.reject! { |event| ignored_probe_failure?(event) }
          bad
        end
      end

      # if the pod is still running we stream the logs until it times out to get as much info as possible
      # necessary since logs often hang for a while even if the pod is already done
      def fetch_logs(container, end_time, previous:)
        name = @pod.dig_fetch(:metadata, :name)
        namespace = @pod.dig_fetch(:metadata, :namespace)

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

      def ignored_probe_failure?(event)
        return false unless event[:reason] == "Unhealthy"
        return false unless probe = event[:message][/\A(\S+) probe failed/, 1]
        return false unless threshold = failure_threshold(event, :"#{probe.downcase}Probe")
        event[:count] < threshold
      end

      # per http://kubernetes.io/docs/api-reference/v1/definitions/ default is 3
      # by default checks every 10s so that gives us 30s to pass
      def failure_threshold(event, probe_name)
        return unless container_name = event.dig(:involvedObject, :fieldPath).to_s[/\Aspec.containers{(.*)}\z/, 1]
        return unless container = @pod.dig(:spec, :containers).detect { |c| c[:name] == container_name }
        return unless probe = container[probe_name]
        probe[:failureThreshold] || 3
      end

      def ready?
        @pod.dig(:status, :conditions)&.detect { |c| c[:type] == 'Ready' && c[:status] == 'True' }
      end
    end
  end
end
