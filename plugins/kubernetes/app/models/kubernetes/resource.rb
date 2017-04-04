# frozen_string_literal: true
module Kubernetes
  # abstraction for interacting with kubernetes resources
  # ... could be merged with Kubernetes::Api counterparts
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

      def delete
        request(:delete, name, namespace)
        expire_cache
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

      # TODO: test for actual hash / usability ...
      def request(method, *args)
        client.send("#{method}_#{@template.fetch(:kind).underscore}", *args)
      end

      def client
        @deploy_group.kubernetes_cluster.client
      end

      def loop_sleep
        sleep 2 unless Rails.env == 'test'
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
      def delete
        return unless resource

        # Make kubenretes kill all the pods by scaling down
        @template[:spec][:replicas] = 0
        update

        # Wait for there to be zero pods
        loop do
          loop_sleep
          break if fetch_resource[:status][:replicas].to_i.zero?
        end

        # delete the actual deployment
        super
      end

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

      def client
        @deploy_group.kubernetes_cluster.extension_client
      end
    end

    class DaemonSet < Base
      def deploy
        delete if running?
        create
      end

      # we cannot replace or update a daemonset, so we take it down completely
      #
      # was do what `kubectl delete daemonset NAME` does:
      # - make it match no node
      # - waits for current to reach 0
      # - deletes the daemonset
      def delete
        return super if no_pods_running? # delete when already dead from previous deletion try, update would fail

        # make it match no node
        @template[:spec][:template][:spec][:nodeSelector] = {rand(9999).to_s => rand(9999).to_s}
        update

        # wait for it to terminate all it's pods
        max = 30
        (1..max).each do |i|
          loop_sleep
          expire_cache
          break if no_pods_running?
          if i == max
            raise Samson::Hooks::UserError, "Unable to terminate previous DaemonSet because it still has pods"
          end
        end

        # delete it
        super
      end

      # need http request since we do not know how many nodes we will match
      # and the number of matches nodes could update with a changed template
      # only makes sense to call this after deploying / while waiting for pods
      def desired_pod_count
        return 0 if @template[:spec][:replicas].to_i.zero?
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

      def no_pods_running?
        resource[:status][:currentNumberScheduled].zero? && resource[:status][:numberMisscheduled].zero?
      end

      def client
        @deploy_group.kubernetes_cluster.extension_client
      end
    end

    class Job < Base
      def deploy
        delete if running?
        create
      end

      def desired_pod_count
        @template[:spec][:replicas]
      end

      def revert(_previous)
        delete
      end

      # deleting the job leaves the pods running, so we have to delete them manually
      # kubernetes is a little more careful with running pods, but we just want to get rid of them
      def delete
        selector = resource.dig(:spec, :selector, :matchLabels).map { |k, v| "#{k}=#{v}" }.join(",")

        # delete the job
        super

        # delete the pods
        client = @deploy_group.kubernetes_cluster.client # pod api is not part of the extension client
        pods = client.get_pods(label_selector: selector, namespace: namespace)
        pods.each { |pod| client.delete_pod pod.metadata.name, pod.metadata.namespace }
      end

      private

      # FYI per docs it is supposed to use batch api, but extension api works
      def client
        @deploy_group.kubernetes_cluster.extension_client
      end
    end

    class Pod < Base
      def deploy
        delete if running?
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
