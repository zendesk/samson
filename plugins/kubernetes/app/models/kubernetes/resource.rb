# frozen_string_literal: true
module Kubernetes
  # abstraction for interacting with kubernetes resources
  #
  # Add a new resource:
  # run an example file through `kubectl create/replace/delete -f test.yml -v8`
  # and see what it does internally ... simple create/update/delete requests or special magic ?
  module Resource
    class Base
      def initialize(template, deploy_group)
        @template = template
        @deploy_group = deploy_group
      end

      def name
        @template.fetch(:metadata).fetch(:name)
      end

      def namespace
        @template.fetch(:metadata).fetch(:namespace)
      end

      # should it be deployed before all other things get deployed ?
      def prerequisite?
        @template.dig(*RoleConfigFile::PREREQUISITE)
      end

      def primary?
        Kubernetes::RoleConfigFile::PRIMARY_KINDS.include?(@template.fetch(:kind))
      end

      def deploy
        running? ? update : create
      end

      def revert(previous)
        if previous
          self.class.new(previous, @deploy_group).deploy
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
        [0.0, 0.1, 0.2, 0.5, 1, 2, 4, 8, 16].each do |wait|
          expire_cache
          return true unless running?
          sleep wait
        end
        raise "Unable to delete resource"
      end

      def running?
        !!resource
      end

      def resource
        return @resource if defined?(@resource)
        @resource = fetch_resource
      end

      def uid
        resource&.fetch(:metadata)&.fetch(:uid)
      end

      private

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
        request(:update, @template)
        expire_cache
      end

      def fetch_resource
        request(:get, name, namespace).to_hash
      rescue KubeException => e
        raise e unless e.error_code == 404
        nil
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

    class Service < Base
      # ideally we should update, but that is not supported
      # and delete+create would mean interrupting service
      # TODO: warn users when a change needs to be made but could not be done
      def deploy
        return if running?
        create
      end

      def revert(previous)
        delete unless previous
      end
    end

    class Deployment < Base
      def desired_pod_count
        @template[:spec][:replicas]
      end

      def revert(previous)
        if previous
          client.rollback_deployment(name, namespace)
        else
          delete
        end
      end

      private

      def request_delete
        # Make kubernetes kill all the pods by scaling down
        restore_template do
          @template[:spec][:replicas] = 0
          update
        end

        # Wait for there to be zero pods
        loop do
          loop_sleep
          break if fetch_resource[:status][:replicas].to_i.zero?
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
          desired = resource[:status][:desiredNumberScheduled]
          return desired unless desired.zero?

          # in bad state or does not yet know how many it needs
          loop_sleep
          expire_cache

          desired = resource[:status][:desiredNumberScheduled]
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
          @template[:spec][:template][:spec][:nodeSelector] = {rand(9999).to_s => rand(9999).to_s}
          update
        end

        wait_for_termination_of_all_pods
        super # delete it
      end

      def no_pods_running?
        resource[:status][:currentNumberScheduled].zero? && resource[:status][:numberMisscheduled].zero?
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
      def desired_pod_count
        @template[:spec][:replicas]
      end

      private

      def client
        @deploy_group.kubernetes_cluster.apps_client
      end
    end

    class Job < Base
      def deploy
        delete
        create
      end

      def desired_pod_count
        @template[:spec][:replicas]
      end

      def revert(_previous)
        delete
      end

      private

      # deleting the job leaves the pods running, so we have to delete them manually
      # kubernetes is a little more careful with running pods, but we just want to get rid of them
      def request_delete
        selector = resource.dig(:spec, :selector, :matchLabels).map { |k, v| "#{k}=#{v}" }.join(",")

        # delete the job
        super

        # delete the pods
        client = @deploy_group.kubernetes_cluster.client # pod api is not part of the extension client
        pods = client.get_pods(label_selector: selector, namespace: namespace)
        pods.each { |pod| client.delete_pod pod.metadata.name, pod.metadata.namespace }
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
