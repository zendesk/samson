# frozen_string_literal: true
# TODO: merge plugins/kubernetes/app/models/kubernetes/api/pod.rb into here
module Kubernetes
  class ResourceStatus
    attr_reader :resource, :role, :deploy_group, :kind, :details, :live, :finished, :pod
    attr_writer :details

    def initialize(resource:, role: nil, deploy_group:, prerequisite: false, start:, kind: resource.fetch(:kind))
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
        elsif @pod.restarted?
          @details = "Restarted"
          @finished = true
        elsif @pod.failed?
          @details = "Failed"
          @finished = true
        elsif @prerequisite ? @pod.completed? : @pod.live?
          @details = "Live"
          @live = true
          @finished = @pod.completed?
        elsif (@pod.events = events) && @pod.waiting_for_resources?
          @details = "Waiting for resources (#{@pod.phase}, #{@pod.reason})"
        elsif @pod.events_indicate_failure?
          @details = "Error event"
          @finished = true
        else
          @details = "Waiting (#{@pod.phase}, #{@pod.reason})"
        end
      end
    end

    def events
      # do not rely on uid, when creation fails we don't get one
      SamsonKubernetes.retry_on_connection_errors do
        events = @client.get_events(
          namespace: @resource.dig_fetch(:metadata, :namespace),
          field_selector: "involvedObject.name=#{@resource.dig_fetch(:metadata, :name)},involvedObject.kind=#{@kind}"
        ).fetch(:items)

        # ignore events from before the deploy, comparing strings for speed
        events.select! { |e| e.dig(:metadata, :creationTimestamp) >= @start }

        # https://github.com/kubernetes/kubernetes/issues/29838
        events.sort_by! { |e| e.dig(:metadata, :creationTimestamp) }

        events
      end
    end
  end
end
