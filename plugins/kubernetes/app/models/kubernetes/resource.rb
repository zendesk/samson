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

      def deploy
        running? ? update : create
      end

      def delete
        request(:delete, name, namespace)
        remove_instance_variable(:@resource) if @resource
      end

      def running?
        !!resource
      end

      # TODO: caching might not be necessary and just complicating things ...
      def resource
        return @resource if defined?(@resource)
        @resource = fetch_resource
      end

      private

      def create
        request(:create, @template)
      end

      # FYI: do not use result, see https://github.com/abonas/kubeclient/issues/196
      def update
        request(:update, @template)
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
        sleep 2 unless ENV.fetch('RAILS_ENV') == 'test'
      end
    end

    class Service < Base
      # deleting a service is never and option since it would interrupt the service
      # TODO: warn users when a change needs to be made but could not be done
      def deploy
        return if running?
        create
      end
    end

    class Deployment < Base
      def delete
        return unless resource

        # Make kubenretes kill all the pods by scaling down
        resource[:spec][:replicas] = 0
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
        # make it match no node
        @template[:spec][:template][:spec][:nodeSelector] = {rand(9999).to_s => rand(9999).to_s}
        update

        # wait for it to terminate all it's pods
        max = 30
        (1..max).each do |i|
          loop_sleep
          current = fetch_resource
          scheduled = current[:status][:currentNumberScheduled]
          misscheduled = current[:status][:numberMisscheduled]
          break if scheduled.zero? && misscheduled.zero?
          if i == max
            raise(
              Samson::Hooks::UserError,
              "Unable to terminate previous DaemonSet, scheduled: #{scheduled} / misscheduled: #{misscheduled}\n"
            )
          end
        end

        # delete it
        super
      end

      # need http request since we do not know how many nodes we will match
      # and the number of matches nodes could update with a changed template
      # only makes sense to call this after deploying / while waiting for pods
      def desired_pod_count
        @desired_pod_count ||= fetch_resource[:status][:desiredNumberScheduled]
      end

      private

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

      private

      # FYI per docs it is supposed to use batch api, but extension api works
      def client
        @deploy_group.kubernetes_cluster.extension_client
      end
    end

    def self.build(*args)
      "Kubernetes::Resource::#{args.first.fetch(:kind)}".constantize.new(*args)
    end
  end
end
