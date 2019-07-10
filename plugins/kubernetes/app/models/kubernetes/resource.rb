# frozen_string_literal: true
require 'samson/retry' # avoid race condition when using multiple threads to do kubeclient requests which use retry

module Kubernetes
  # abstraction for interacting with kubernetes resources
  #
  # Add a new resource:
  # run an example file through `kubectl create/replace/delete -f test.yml -v8`
  # and see what it does internally ... simple create/update/delete requests or special magic ?
  module Resource
    class Base
      TICK = 2 # seconds
      UNSETTABLE_METADATA = [:selfLink, :uid, :resourceVersion, :generation, :creationTimestamp].freeze
      attr_reader :template, :deploy_group

      def initialize(template, deploy_group, autoscaled:, delete_resource:)
        @template = template
        @deploy_group = deploy_group
        @autoscaled = autoscaled
        @delete_resource = delete_resource
      end

      def name
        @template.dig_fetch(:metadata, :name)
      end

      def namespace
        @template.dig(:metadata, :namespace)
      end

      # should it be deployed before all other things get deployed ?
      def prerequisite?
        @template.dig(*RoleConfigFile::PREREQUISITE)
      end

      def deploy
        if exist?
          if @delete_resource
            delete
          else
            update
          end
        else
          create
        end
      end

      def revert(previous)
        if previous
          # Avoid "the object has been modified" / "Precondition failed: UID in precondition" error
          # by removing internal attributes kubernetes adds
          previous = previous.deep_dup
          previous[:metadata].except! *UNSETTABLE_METADATA
          self.class.new(previous, @deploy_group, autoscaled: @autoscaled, delete_resource: false).deploy
        else
          delete
        end
      end

      # wait for delete to finish before doing further work so we don't run into duplication errors
      # - first wait is 0 since the request itself already took a few ms
      # - sum of waits should be ~30s which is the default delete timeout
      def delete
        return true unless exist?
        request_delete
        backoff_wait([0.0, 0.1, 0.2, 0.5, 1, 2, 4, 8, 16], "delete resource") do
          expire_resource_cache
          return true unless exist?
        end
      end

      def exist?
        !!resource
      end

      def resource
        return @resource if defined?(@resource)
        @resource = fetch_resource
      end

      def uid
        resource&.dig_fetch(:metadata, :uid)
      end

      def kind
        @template.fetch(:kind)
      end

      def desired_pod_count
        if @delete_resource
          0
        else
          @template.dig(:spec, :replicas) || (RoleConfigFile.primary?(@template) ? 1 : 0)
        end
      end

      private

      def error_location
        "#{name} #{namespace} #{@deploy_group.name}"
      end

      def backoff_wait(backoff, reason)
        backoff.each do |wait|
          yield
          sleep wait
        end
        raise "Unable to #{reason} (#{error_location})"
      end

      def request_delete
        request(:delete, name, namespace)
        expire_resource_cache
      end

      def expire_resource_cache
        remove_instance_variable(:@resource) if defined?(@resource)
      end

      # TODO: remove the expire_cache and assign @resource but that breaks a bunch of deploy_executor tests
      def create
        return if @delete_resource
        restore_template do
          request(:create, @template)
        end
        expire_resource_cache
      rescue Kubeclient::ResourceNotFoundError => e
        raise_kubernetes_error(e.message)
      end

      # TODO: remove the expire_cache and assign @resource but that breaks a bunch of deploy_executor tests
      def update
        ensure_not_updating_match_labels
        request(:update, template_for_update)
        expire_resource_cache
      end

      def ensure_not_updating_match_labels
        # blue-green deploy is allowed to do this, see template_filler.rb + deploy_executor.rb
        return if @template.dig(:spec, :selector, :matchLabels, :blue_green)

        # allow manual migration when user is aware of the issue and wants to do manual cleanup
        return if @template.dig(:metadata, :annotations, :"samson/allow_updating_match_labels") == "true"

        static = [:spec, :selector, :matchLabels]
        # fallback is only for tests that use simple replies
        old_labels = @resource.dig(*static) || {}
        new_labels = @template.dig(*static) || {}

        if new_labels.any? { |k, v| old_labels[k] != v }
          raise(
            Samson::Hooks::UserError,
            "Updating #{static.join(".")} from #{old_labels.inspect} to #{new_labels.inspect} " \
            "can only be done by deleting and redeploying or old pods would not be deleted."
          )
        end
      end

      def template_for_update
        copy = @template.deep_dup

        # when autoscaling on a resource with replicas we should keep replicas constant
        # (not setting replicas will make it use the default of 1)
        path = [:spec, :replicas]
        replica_source = (@autoscaled && resource) || @template
        copy.dig_set(path, replica_source.dig(*path)) if @template.dig(*path)

        # copy fields
        persistent_fields.each do |keep|
          path = keep.split(".").map!(&:to_sym)
          old_value = resource.dig(*path)
          copy.dig_set path, old_value unless old_value.nil? # boolean fields are kept, but nothing is nil in kubernetes
        end

        copy
      end

      def persistent_fields
        []
      end

      def fetch_resource
        ignore_404 do
          request(:get, name, namespace)
        end
      end

      def pods
        ids = resource.dig_fetch(:spec, :template, :metadata, :labels).values_at(:release_id, :deploy_group_id)
        selector = Kubernetes::Release.pod_selector(*ids, query: true)
        pod_client.get_pods(label_selector: selector, namespace: namespace).fetch(:items)
      end

      def delete_pods
        old_pods = pods
        yield if block_given?
        old_pods.each do |pod|
          ignore_404 do
            pod_client.delete_pod pod.dig_fetch(:metadata, :name), pod.dig_fetch(:metadata, :namespace)
          end
        end
      end

      def request(verb, *args)
        SamsonKubernetes.retry_on_connection_errors do
          begin
            method = "#{verb}_#{Kubeclient::ClientMixin.underscore_entity(kind)}"
            if client.respond_to? method
              client.send(method, *args)
            else
              raise(
                Samson::Hooks::UserError,
                "apiVersion #{@template.fetch(:apiVersion)} does not support #{kind}. " \
                "Check kubernetes docs for correct apiVersion"
              )
            end
          rescue Kubeclient::HttpError => e
            message = e.message.to_s
            if verb != :get && e.error_code == 409
              # Update version and retry if we ran into a conflict from VersionedUpdate
              args[0][:metadata][:resourceVersion] = fetch_resource.dig(:metadata, :resourceVersion)
              raise # retry
            elsif message.include?(" is invalid:") || message.include?(" no kind ")
              raise_kubernetes_error(message)
            else
              e.message.insert(0, "Kubernetes error #{error_location}: ") unless e.message.frozen?
              raise
            end
          end
        end
      end

      def raise_kubernetes_error(message)
        raise Samson::Hooks::UserError, "Kubernetes error #{error_location}: #{message}"
      end

      def client
        @deploy_group.kubernetes_cluster.client(@template.fetch(:apiVersion))
      end

      def pod_client
        @deploy_group.kubernetes_cluster.client('v1')
      end

      def restore_template
        original = @template
        @template = original.deep_dup
        yield
      ensure
        @template = original
      end

      def ignore_404
        yield
      rescue Kubeclient::ResourceNotFoundError
        nil
      end
    end

    class Immutable < Base
      def deploy
        delete
        create
      end
    end

    # normally we don't want to set the resourceVersion since that causes conflicts when our version is out of date
    # but some resources require it to be set or fail with "metadata.resourceVersion: must be specified for an update"
    class VersionedUpdate < Base
      def template_for_update
        t = super
        t[:metadata][:resourceVersion] = resource.dig(:metadata, :resourceVersion)
        t
      end
    end

    class Service < VersionedUpdate
      private

      # updating a service requires re-submitting clusterIP
      # we also keep whitelisted fields that are manually changed for load-balancing
      # (meant for labels, but other fields could work too)
      def persistent_fields
        [
          "spec.clusterIP",
          *ENV["KUBERNETES_SERVICE_PERSISTENT_FIELDS"].to_s.split(/\s,/),
          *@template.dig(:metadata, :annotations, :"samson/persistent_fields").to_s.split(/[,\s]+/)
        ]
      end
    end

    class Deployment < Base
      def request_delete
        # Make kubernetes kill all the pods by scaling down
        restore_template do
          @template.dig_set [:spec, :replicas], 0
          update
        end

        # Wait for there to be zero pods
        loop do
          sleep TICK
          # prevent cases when status.replicas are missing
          # e.g. running locally on Minikube, after scale replicas to zero
          # $ kubectl scale deployment {DEPLOYMENT_NAME} --replicas 0
          # "replicas" key is actually removed from "status" map
          # $ {"status":{"conditions":[...],"observedGeneration":2}}
          break if fetch_resource.dig(:status, :replicas).to_i == 0
        end

        # delete the actual deployment
        super
      end
    end

    class DaemonSet < Base
      def deploy
        delete
        create
      end

      # need http request since we do not know how many nodes we will match
      # and the number of matches nodes could update with a changed template
      # only makes sense to call this after deploying / while waiting for pods
      def desired_pod_count
        @desired_pod_count ||= begin
          return 0 if @delete_resource

          desired = 0

          3.times do |i|
            if i != 0
              # last iteration had bad state or does not yet know how many it needs, expire cache
              sleep TICK
              expire_resource_cache
            end

            desired = resource.dig_fetch :status, :desiredNumberScheduled
            break if desired != 0
          end

          # check if we still failed on the last try
          if desired == 0
            raise(
              Samson::Hooks::UserError,
              "Unable to find desired number of pods for DaemonSet #{error_location}\n" \
              "delete it manually and make sure there is at least 1 node schedulable."
            )
          end

          desired
        end
      end

      private

      # we cannot replace or update a daemonset, so we take it down completely
      #
      # was do what `kubectl delete daemonset NAME` does:
      # - make it match no node
      # - waits for current to reach 0
      # - deletes the daemonset
      def request_delete
        return super if pods_count == 0 # delete when already dead from previous deletion try, update would fail

        # make it match no node
        restore_template do
          @template.dig_set [:spec, :template, :spec, :nodeSelector], rand(9999).to_s => rand(9999).to_s
          update
        end

        delete_pods { wait_for_termination_of_all_pods }

        super # delete it
      end

      def pods_count
        resource.dig_fetch(:status, :currentNumberScheduled) + resource.dig_fetch(:status, :numberMisscheduled)
      end

      def wait_for_termination_of_all_pods
        30.times do
          sleep TICK
          expire_resource_cache
          return if pods_count == 0
        end
      end
    end

    class StatefulSet < Base
      def patch_replace?
        return false if @delete_resource || !exist?
        deprecated = @template.dig(:spec, :updateStrategy) # supporting pre 1.9 clusters
        strategy = (deprecated.is_a?(String) ? deprecated : @template.dig(:spec, :updateStrategy, :type))
        [nil, "OnDelete"].include?(strategy)
      end

      # StatefulSet cannot be updated normally when OnDelete is used or kubernetes <1.7
      # So we patch and then delete all pods to let them re-create
      def deploy
        return super unless patch_replace?

        # update the template via special magic
        # https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/#on-delete
        # fails when trying to update anything outside of containers or replicas
        update = resource.deep_dup
        [[:spec, :replicas], [:spec, :template, :spec, :containers]].each do |keys|
          update.dig_set keys, @template.dig_fetch(*keys)
        end
        with_patch_header do
          request :patch, name, [{op: "replace", path: "/spec", value: update.fetch(:spec)}], namespace
        end

        # pods will restart with updated settings
        # need to wait here or deploy_executor.rb will instantly finish since everything is running
        wait_for_pods_to_restart
      end

      def delete
        delete_pods { super }
      end

      private

      def wait_for_pods_to_restart
        old_pods = delete_pods
        old_created = old_pods.map { |pod| pod.dig_fetch(:metadata, :creationTimestamp) }
        backoff_wait(Array.new(60) { 2 }, "restart pods") do
          return if pods.none? { |pod| old_created.include?(pod.dig_fetch(:metadata, :creationTimestamp)) }
        end
      end

      # https://github.com/abonas/kubeclient/issues/268
      def with_patch_header
        old = client.headers['Content-Type']
        client.headers['Content-Type'] = 'application/json-patch+json'
        yield
      ensure
        client.headers['Content-Type'] = old
      end
    end

    class Job < Immutable
      def revert(_previous)
        delete
      end

      private

      # deleting the job leaves the pods running, so we have to delete them manually
      # kubernetes is a little more careful with running pods, but we just want to get rid of them
      def request_delete
        delete_pods { super }
      end
    end

    class CronJob < VersionedUpdate
      def desired_pod_count
        0 # we don't know when it will run
      end
    end

    class Pod < Immutable
    end

    class PodDisruptionBudget < Immutable
      def initialize(*)
        super
        @delete_resource ||= @template[:delete] # allow deletion through release_doc logic
      end
    end

    class APIService < Immutable
    end

    class Namespace < Base
      # Noop because we are scared ... should later only allow deletion if samson created it
      def delete
      end
    end

    class HorizontalPodAutoscaler < Base
    end

    def self.build(*args)
      klass = "Kubernetes::Resource::#{args.first.fetch(:kind)}".safe_constantize || VersionedUpdate
      klass.new(*args)
    end
  end
end
