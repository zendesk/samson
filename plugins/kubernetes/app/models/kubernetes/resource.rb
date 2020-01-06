# frozen_string_literal: true
require 'samson/retry' # avoid race condition when using multiple threads to do kubeclient requests which use retry

module Kubernetes
  # abstraction for interacting with kubernetes resources
  #
  # Add a new resource:
  # run an example file through `kubectl create/replace/delete -f test.yml -v8`
  # and see what it does internally ... simple create/update/delete requests or special magic ?
  module Resource
    module PatchReplace
      def patch_replace?
        !@delete_resource && !server_side_apply? && exist?
      end

      # Some kinds can be updated only using PATCH requests.
      def deploy
        return super unless patch_replace?
        patch_replace
      end

      private

      def patch_replace
        update = resource.deep_dup
        patch_paths.each do |keys|
          update.dig_set keys, @template.dig_fetch(*keys)
        end
        with_header 'application/json-patch+json' do
          request :patch, name, [{op: "replace", path: "/spec", value: update.fetch(:spec)}], namespace
        end
      end
    end

    class Base
      TICK = 2 # seconds
      UNSETTABLE_METADATA = [:selfLink, :uid, :resourceVersion, :generation, :creationTimestamp, :managedFields].freeze
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

      def server_side_apply?
        @template.dig(:metadata, :annotations, :"samson/server_side_apply") == "true"
      end

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
          if server_side_apply?
            server_side_apply @template
          else
            request :create, @template
          end
        end
        expire_resource_cache
      rescue Kubeclient::ResourceNotFoundError => e
        raise Samson::Hooks::UserError, e.message
      end

      # TODO: remove the expire_cache and assign @resource but that breaks a bunch of deploy_executor tests
      def update
        ensure_not_updating_match_labels
        if server_side_apply?
          server_side_apply template_for_update
        else
          request :update, template_for_update
        end
        expire_resource_cache
      rescue Samson::Hooks::UserError => e
        raise unless e.message.match?(/cannot change|Forbidden: updates to .* for fields other than/)

        path = [:metadata, :annotations, :"samson/force_update"]
        if @template.dig(*path) == "true"
          delete
          create
        else
          raise Samson::Hooks::UserError, "#{e.message} (#{path.join(".")}=\"true\" to recreate)"
        end
      end

      # TODO: remove name hack https://github.com/abonas/kubeclient/issues/427
      def server_side_apply(template)
        with_header 'application/apply-patch+yaml' do # NOTE: we send json but say +yaml since +json gives a 415
          request(:patch, "#{name}?fieldManager=samson&force=true", template, namespace)
        end
      end

      # https://github.com/abonas/kubeclient/issues/268
      def with_header(header)
        kubeclient = client
        old = kubeclient.headers['Content-Type']
        kubeclient.headers['Content-Type'] = header
        yield
      ensure
        kubeclient.headers['Content-Type'] = old
      end

      def ensure_not_updating_match_labels
        return if @delete_resource # deployments do an update when deleting

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

        # when updating a autoscaling resource we should keep replicas constant unless we are trying to delete
        # (not setting replicas will make it use the default of 1)
        path = [:spec, :replicas]
        if @autoscaled && resource && copy.dig(*path).to_i != 0
          copy.dig_set(path, resource.dig(*path))
        end

        # copy fields
        persistent_fields.each do |keep|
          path = TemplateFiller.dig_path(keep)
          old_value = resource.dig(*path)
          copy.dig_set path, old_value unless old_value.nil? # boolean fields are kept, but nothing is nil in kubernetes
        end

        copy
      end

      def persistent_fields
        [*@template.dig(:metadata, :annotations, :"samson/persistent_fields").to_s.split(/[,\s]+/)]
      end

      def fetch_resource
        ignore_404 do
          request(:get, name, namespace)
        end
      end

      def pods
        ids = resource.dig_fetch(:spec, :template, :metadata, :labels).values_at(:release_id, :deploy_group_id)
        selector = Kubernetes::Release.pod_selector(*ids, query: true)
        client_request(pod_client, :get_pods, label_selector: selector, namespace: namespace).fetch(:items)
      end

      def delete_pods
        old_pods = pods
        yield
        old_pods.each do |pod|
          ignore_404 do
            client_request(
              pod_client,
              :delete_pod,
              pod.dig_fetch(:metadata, :name),
              pod.dig_fetch(:metadata, :namespace)
            )
          end
        end
      end

      def request(verb, *args)
        SamsonKubernetes.retry_on_connection_errors do
          begin
            method = "#{verb}_#{Kubeclient::ClientMixin.underscore_entity(kind)}"
            kubeclient = client
            if kubeclient.respond_to? method
              client_request(kubeclient, method, *args)
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
              raise Samson::Hooks::UserError, e.message
            else
              raise
            end
          end
        end
      end

      # request but instrument the error before sending it up
      #
      # having our own error type would be better, but that requires refactoring in retry_on_connection_errors
      # and ideally never calling kube-client directly but always throug a wrapper
      def client_request(kubeclient, *args)
        kubeclient.send(*args)
      rescue Kubeclient::HttpError => e
        e.message.insert(0, "Kubernetes error #{error_location}: ") unless e.message.frozen?
        raise
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
        super + [
          "spec.clusterIP",
          *(@template.dig(:spec, :ports) || []).each_with_index.map { |_, i| "spec.ports.#{i}.nodePort" },
          *ENV["KUBERNETES_SERVICE_PERSISTENT_FIELDS"].to_s.split(/\s,/)
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
      # need http request since we do not know how many nodes we will match
      # and the number of matches nodes could update with a changed template
      # only makes sense to call this after deploying / while waiting for pods
      def desired_pod_count
        @desired_pod_count ||= begin
          return 0 if @delete_resource

          desired = 0

          6.times do |i|
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
    end

    # TODO: check that PatchReplace actually still works here
    class PersistentVolumeClaim < Base
      include PatchReplace

      private

      def patch_paths
        [[:spec, :resources, :requests]]
      end
    end

    class StatefulSet < Base
      def deploy
        if [[:spec, :updateStrategy, :type], [:spec, :updateStrategy]].any? { |p| @template.dig(*p) == "OnDelete" }
          raise Samson::Hooks::UserError, "StatefulSet OnDelete strategy is no longer supported, use RollingUpdate"
        end

        super
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

    class ServiceAccount < VersionedUpdate
      def template_for_update
        t = super
        t[:secrets] ||= resource[:secrets]
        t
      end
    end

    def self.build(*args)
      klass = "Kubernetes::Resource::#{args.first.fetch(:kind)}".safe_constantize || VersionedUpdate
      klass.new(*args)
    end
  end
end
