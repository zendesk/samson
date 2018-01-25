# frozen_string_literal: true
module Kubernetes
  # abstraction for interacting with kubernetes resources
  #
  # Add a new resource:
  # run an example file through `kubectl create/replace/delete -f test.yml -v8`
  # and see what it does internally ... simple create/update/delete requests or special magic ?
  module Resource
    class Base
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
        @template.dig_fetch(:metadata, :namespace)
      end

      # should it be deployed before all other things get deployed ?
      def prerequisite?
        @template.dig(*RoleConfigFile::PREREQUISITE)
      end

      def primary?
        Kubernetes::RoleConfigFile::PRIMARY_KINDS.include?(@template.fetch(:kind))
      end

      def deploy
        if running?
          if @delete_resource
            delete
          else
            update
          end
        else
          create unless @delete_resource
        end
      end

      def revert(previous)
        if previous
          self.class.new(previous, @deploy_group, autoscaled: @autoscaled, delete_resource: false).deploy
        else
          delete
        end
      end

      # wait for delete to finish before doing further work so we don't run into duplication errors
      # - first wait is 0 since the request itself already took a few ms
      # - sum of waits should be ~30s which is the default delete timeout
      def delete
        return true unless running?
        request_delete
        backoff_wait([0.0, 0.1, 0.2, 0.5, 1, 2, 4, 8, 16], "delete resource") do
          expire_cache
          return true unless running?
        end
      end

      def running?
        !!resource
      end

      def resource
        return @resource if defined?(@resource)
        @resource = fetch_resource
      end

      def uid
        resource&.dig_fetch(:metadata, :uid)
      end

      def desired_pod_count
        replica_source.dig_fetch(:spec, :replicas)
      end

      private

      # when autoscaling we expect as many pods as we currently have
      def replica_source
        (@autoscaled && resource) || @template
      end

      def backoff_wait(backoff, reason)
        backoff.each do |wait|
          yield
          sleep wait
        end
        raise "Unable to #{reason}"
      end

      def request_delete
        request(:delete, name, namespace)
        expire_cache
      end

      def expire_cache
        remove_instance_variable(:@resource) if defined?(@resource)
      end

      def create
        request(:create, @template)
        expire_cache
      end

      # FYI: do not use result of update call, see https://github.com/abonas/kubeclient/issues/196
      def update
        request(:update, template_for_update)
        expire_cache
      end

      def template_for_update
        copy = @template.deep_dup

        # when autoscaling on a resource with replicas we should keep replicas constant
        # (not setting replicas will make it use the default of 1)
        path = [:spec, :replicas]
        copy.dig_set(path, replica_source.dig(*path)) if @template.dig(*path)

        copy
      end

      def fetch_resource
        reply = request(:get, name, namespace, as: :raw)
        JSON.parse(reply, symbolize_names: true)
      rescue *SamsonKubernetes.connection_errors => e
        raise e unless e.respond_to?(:error_code) && e.error_code == 404
        nil
      end

      def pods
        ids = resource.dig_fetch(:spec, :template, :metadata, :labels).values_at(:release_id, :deploy_group_id)
        selector = Kubernetes::Release.pod_selector(*ids, query: true)
        pod_client.get_pods(label_selector: selector, namespace: namespace).map(&:to_hash)
      end

      def delete_pods(pods)
        pods.each do |pod|
          pod_client.delete_pod pod.dig_fetch(:metadata, :name), pod.dig_fetch(:metadata, :namespace)
        end
      end

      def request(method, *args)
        client.send("#{method}_#{@template.fetch(:kind).underscore}", *args)
      rescue
        message = $!.message.to_s
        if message.include?(" is invalid:") || message.include?(" no kind ")
          raise Samson::Hooks::UserError, "Kubernetes error: #{message}"
        else
          raise
        end
      end

      def client
        pod_client
      end

      def pod_client
        @deploy_group.kubernetes_cluster.client
      end

      def loop_sleep
        sleep 2 unless Rails.env == 'test'
      end

      def restore_template
        original = @template
        @template = original.deep_dup
        yield
      ensure
        @template = original
      end
    end

    class ConfigMap < Base
    end

    class HorizontalPodAutoscaler < Base
      private

      def client
        @deploy_group.kubernetes_cluster.autoscaling_client
      end
    end

    class Service < Base
      private

      # updating a service requires re-submitting resourceVersion and clusterIP
      # we also keep whitelisted fields that are manually changed for load-balancing
      # (meant for labels, but other fields could work too)
      def template_for_update
        copy = super
        [
          "metadata.resourceVersion",
          "spec.clusterIP",
          *ENV["KUBERNETES_SERVICE_PERSISTENT_FIELDS"].to_s.split(",")
        ].each do |keep|
          path = keep.split(".").map!(&:to_sym)
          old_value = resource.dig(*path)
          copy.dig_set path, old_value unless old_value.nil? # boolean fields are kept, but nothing is nil in kubernetes
        end
        copy
      end
    end

    class Deployment < Base
      # Avoid "the object has been modified" error by removing internal attributes kubernetes adds
      def revert(previous)
        if previous
          previous = previous.deep_dup
          previous[:metadata].except! :selfLink, :uid, :resourceVersion, :generation, :creationTimestamp
        end
        super
      end

      private

      def request_delete
        # Make kubernetes kill all the pods by scaling down
        restore_template do
          @template.dig_set [:spec, :replicas], 0
          update
        end

        # Wait for there to be zero pods
        loop do
          loop_sleep
          # prevent cases when status.replicas are missing
          # e.g. running locally on Minikube, after scale replicas to zero
          # $ kubectl scale deployment {DEPLOYMENT_NAME} --replicas 0
          # "replicas" key is actually removed from "status" map
          # $ {"status":{"conditions":[...],"observedGeneration":2}}
          break if fetch_resource.dig(:status, :replicas).to_i.zero?
        end

        # delete the actual deployment
        super
      end

      def client
        @deploy_group.kubernetes_cluster.extension_client
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
          desired = resource.dig_fetch :status, :desiredNumberScheduled
          return desired unless desired.zero?

          # in bad state or does not yet know how many it needs
          loop_sleep
          expire_cache

          desired = resource.dig_fetch :status, :desiredNumberScheduled
          return desired unless desired.zero?

          raise(
            Samson::Hooks::UserError,
            "Unable to find desired number of pods for daemonset #{name}\n" \
            "delete it manually and make sure there is at least 1 node scheduleable."
          )
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
        return super if no_pods_running? # delete when already dead from previous deletion try, update would fail

        # make it match no node
        restore_template do
          @template.dig_set [:spec, :template, :spec, :nodeSelector], rand(9999).to_s => rand(9999).to_s
          update
        end

        wait_for_termination_of_all_pods
        super # delete it
      end

      def no_pods_running?
        resource.dig_fetch(:status, :currentNumberScheduled).zero? &&
          resource.dig_fetch(:status, :numberMisscheduled).zero?
      end

      def client
        @deploy_group.kubernetes_cluster.extension_client
      end

      def wait_for_termination_of_all_pods
        30.times do
          loop_sleep
          expire_cache
          return if no_pods_running?
        end
        raise Samson::Hooks::UserError, "Unable to terminate previous DaemonSet because it still has pods"
      end
    end

    class StatefulSet < Base
      def patch_replace?
        [nil, "OnDelete"].include?(@template.dig(:spec, :updateStrategy)) && running?
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
        old_pods = pods
        super
        delete_pods(old_pods)
      end

      private

      def wait_for_pods_to_restart
        old_pods = pods
        delete_pods(old_pods)
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

      def client
        @deploy_group.kubernetes_cluster.apps_client
      end
    end

    class Job < Base
      def deploy
        delete
        create
      end

      def revert(_previous)
        delete
      end

      private

      # deleting the job leaves the pods running, so we have to delete them manually
      # kubernetes is a little more careful with running pods, but we just want to get rid of them
      def request_delete
        old_pods = pods
        super # delete the job
        delete_pods(old_pods)
      end

      # FYI per docs it is supposed to use batch api, but extension api works
      def client
        @deploy_group.kubernetes_cluster.batch_client
      end
    end

    class Pod < Base
      def deploy
        delete
        create
      end

      def desired_pod_count
        1
      end
    end

    def self.build(*args)
      "Kubernetes::Resource::#{args.first.fetch(:kind)}".constantize.new(*args)
    end
  end
end
