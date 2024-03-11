# frozen_string_literal: true
# TODO: merge plugins/kubernetes/app/models/kubernetes/api/pod.rb into here
# TODO: rename live to ready to be more consistent with deploy_executor
module Kubernetes
  class ResourceStatus
    IGNORED_EVENT_REASONS = {
      Pod: [
        # These errors may happens when Deployment which uses PVC is updated. Ignore them.
        "FailedAttachVolume",
        "FailedMount"
      ],
      HorizontalPodAutoscaler: [
        "FailedGetMetrics",
        "FailedRescale",
        "FailedGetResourceMetric",
        "FailedGetExternalMetric",
        "FailedComputeMetricsReplicas",
        "FailedUpdateStatus"
      ],
      PodDisruptionBudget: [
        "CalculateExpectedPodCountFailed",
        "NoControllers",
        "NoPods",
        "UnmanagedPods"
      ],
      Service: [
        "FailedToUpdateEndpointSlices"
      ],
      StatefulSet: [
        # Regression from k8s 1.27: https://github.com/kubernetes/kubernetes/pull/115331
        # Pending backport in: https://github.com/kubernetes/kubernetes/pull/121921
        "RecreatingFailedPod"
      ],
      # karmada can fail to sync a resource when something else also updated the resource,
      # this does not necessarily indicate that sync will be broken forever
      All: [
        'ApplyPolicyFailed',
        'SyncFailed'
      ]
    }.freeze

    attr_reader :resource, :role, :deploy_group, :kind, :details, :live, :finished, :pod

    def initialize(resource:, deploy_group:, start:, kind:, role: nil, prerequisite: false)
      @resource = resource
      @kind = kind
      @role = role
      @deploy_group = deploy_group
      @start = start
      @prerequisite = prerequisite
      @client = deploy_group.kubernetes_cluster.client('v1')
    end

    def check
      if kind == "Pod"
        @pod = Kubernetes::Api::Pod.new(@resource, client: @client) if @resource

        if !@resource
          @details = "Missing"
        elsif @details = @pod.restart_details
          @finished = true
        elsif @pod.failed?
          @details = "Failed"
          @finished = true
        elsif @prerequisite ? @pod.completed? : @pod.live?
          @details = "Live"
          @live = true
          @finished = @pod.completed?
        elsif (@pod.events = bad_events(kind)) && @pod.waiting_for_resources? # TODO: rename/refactor pod.events
          @details = "Waiting for resources (#{@pod.phase}, #{@pod.reason})"
        elsif @pod.events_indicate_failure?
          @details = "Error event"
          @finished = true
        else
          @details = "Waiting (#{@pod.phase}, #{@pod.reason})"
        end
      else
        @finished = true # non-pods are never "Missing" because samson creates them directly

        if bad_events(kind).any?
          @details = "Error event"
        else
          @details = "Live"
          @live = true
        end
      end
    end

    # do not rely on uid, when creation fails we don't get one
    def events(type: nil)
      name = @resource.dig_fetch(:metadata, :name)
      namespace = @resource.dig(:metadata, :namespace)
      selector = [
        "involvedObject.name=#{name}",
        "involvedObject.kind=#{@kind}",
      ]
      selector << "involvedObject.uid=#{@pod.uid}" if @pod
      selector << "type=#{type}" if type
      SamsonKubernetes.retry_on_connection_errors do
        events = @client.get_events(
          namespace: namespace,
          field_selector: selector.join(",")
        ).fetch(:items)

        # ignore events from before the deploy, comparing strings for speed
        events.select! { |e| last_timestamp(e) >= @start }

        # https://github.com/kubernetes/kubernetes/issues/29838
        events.sort_by! { |e| last_timestamp(e) }

        events
      end
    rescue *SamsonKubernetes.connection_errors => e
      # similar to kubernetes/resource.rb error handling
      error_location = "#{name} #{namespace} #{@deploy_group.name}"
      raise Samson::Hooks::UserError, "Kubernetes error #{error_location}: #{e.message}"
    end

    private

    # prefer lastTimestamp but sometime it is empty, see https://github.com/eclipse/che/issues/15395
    def last_timestamp(event)
      event[:lastTimestamp] || event.dig(:metadata, :creationTimestamp)
    end

    # ignore known events that randomly happen
    def bad_events(kind)
      failures = events(type: "Warning")
      ignored =
        @resource.dig(:metadata, :annotations, :"samson/ignore_events").to_s.split(",") +
        (IGNORED_EVENT_REASONS[kind.to_sym] || []) +
        IGNORED_EVENT_REASONS[:All]
      failures.reject! { |e| ignored.include? e[:reason] }
      failures
    end
  end
end
