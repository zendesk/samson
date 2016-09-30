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
        remove_instance_variable(:@resource_object) if @resource_object
      end

      def running?
        !!resource_object
      end

      private

      def create
        request(:create, @template)
      end

      # FYI: do not use result, see https://github.com/abonas/kubeclient/issues/196
      def update
        request(:update, @template)
      end

      # TODO: caching might not be necessary and just complicating things ...
      def resource_object
        return @resource_object if defined?(@resource_object)
        @resource_object = fetch_resource
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
        return unless resource_object

        # Make kubenretes kill all the pods by scaling down
        resource_object[:spec][:replicas] = 0
        update

        # Wait for there to be zero pods
        loop do
          loop_sleep
          break if fetch_resource[:status][:replicas].to_i.zero?
        end

        # delete the actual deployment
        super
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
