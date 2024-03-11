# frozen_string_literal: true
require 'samson/retry' # avoid race condition when using multiple threads to do kubeclient requests which use retry

module Kubernetes
  # abstraction for interacting with kubernetes resources
  #
  # Add a new resource:
  # run an example file through `kubectl create/replace/delete -f test.yml -v8`
  # and see what it does internally ... simple create/update/delete requests or special magic ?
  module Resource
    DELETE_BACKOFF = [0.0, 0.1, 0.2, 0.5, 1, 2, 4, 8, 16, 32].freeze # seconds

    module PatchReplace
      def patch_replace?
        !@delete_resource && !server_side_apply? && exist?
      end

      # Some kinds can be updated only using PATCH requests.
      def deploy
        patch_replace? ? patch_replace : super
      end

      private

      def patch_replace
        update = resource.deep_dup
        patch_paths.each do |keys|
          update.dig_set keys, @template.dig_fetch(*keys)
        end
        request :json_patch, name, [{op: "replace", path: "/spec", value: update.fetch(:spec)}], namespace
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
            if recreate?
              delete
              create
            else
              update
            end
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
      # - we wait long because deleting a deployment will wait for all its' pods to go away which can take time
      # - foreground deletion sometimes hangs forever, so suggest to scale to 0 first
      def delete
        return true unless exist?
        request_delete
        error_message = "delete resource (try scaling to 0 first without deletion)"
        backoff_wait(DELETE_BACKOFF, error_message) do
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

      def recreate?
        @template.dig(:metadata, :annotations, :"samson/recreate") == "true"
      end

      def server_side_apply?
        self.class.server_side_apply?(@template)
      end

      public_class_method def self.server_side_apply?(template)
        template.dig(:metadata, :annotations, :"samson/server_side_apply") == "true"
      end

      def error_location
        "#{kind} #{name} #{namespace} #{@deploy_group.name}"
      end

      def backoff_wait(backoff, reason)
        backoff.each do |wait|
          yield
          sleep wait
        end
        raise "Unable to #{reason} (#{error_location})"
      end

      # ensure deletion of child resources like pods before the method completes,
      # to not run into conflicts when deploying the same resource right after
      def request_delete
        # - we saw deployment deletions that did not work in foreground, so allow scale down and then delete
        # - we saw nodeport service deletions handing forever even if they had no endpoints
        propagation = (resource.dig(:spec, :replicas) == 0 || kind == "Service" ? "Background" : "Foreground")
        request(:delete, name, namespace, delete_options: {propagationPolicy: propagation})
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
        sleep 10 if Release::CRD_CREATING.keys.include?(kind)
      rescue Kubeclient::ResourceNotFoundError => e
        raise Samson::Hooks::UserError, e.message
      end

      # TODO: remove the expire_cache and assign @resource but that breaks a bunch of deploy_executor tests
      def update
        if server_side_apply?
          server_side_apply template_for_update
        else
          request :update, template_for_update
        end
        expire_resource_cache
      rescue Samson::Hooks::UserError => e
        raise unless e.message.match?(
          /cannot change|Forbidden: updates to .* for fields other than|Forbidden: may not be used when/
        )

        path = [:metadata, :annotations, :"samson/force_update"]
        if @template.dig(*path) == "true"
          delete
          create
        else
          raise Samson::Hooks::UserError, "#{e.message} (#{path.join(".")}=\"true\" to recreate)"
        end
      end

      def server_side_apply(template)
        request :apply, template, field_manager: "samson", force: true
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
            if verb == :update && e.error_code == 409
              # Update version and retry if we ran into a conflict from VersionedUpdate
              args[0][:metadata][:resourceVersion] = fetch_resource.dig(:metadata, :resourceVersion)
              raise # retry
            elsif message.match?(/ is invalid:| no kind | admission webhook /)
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
      def recreate?
        true
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
    end

    class CronJob < VersionedUpdate
      def desired_pod_count
        0 # we don't know when it will run
      end
    end

    class PodTemplate < VersionedUpdate
      def desired_pod_count
        0 # PodTemplates don't actually create pods
      end
    end

    class Pod < Immutable
    end

    class PodDisruptionBudget < VersionedUpdate
      def initialize(...)
        super(...)
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

    def self.build(*args, **kwargs)
      klass = "Kubernetes::Resource::#{args.first.fetch(:kind)}".safe_constantize || VersionedUpdate
      klass.new(*args, **kwargs)
    end
  end
end
