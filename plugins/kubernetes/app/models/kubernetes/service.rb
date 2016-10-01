# frozen_string_literal: true
module Kubernetes
  # abstraction for interacting with kubernetes service
  class Service
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

    def running?
      !!service_object
    end

    # TODO: update might be a better generic resource interface then having outsiders know about internal state
    def create
      @service_object = client.create_service(@template)
    end

    private

    def service_object
      return @service_object if defined?(@service_object)
      @service_object = begin
        @service_object = client.get_service(name, namespace)
      rescue KubeException => e
        raise e unless e.error_code == 404
        nil
      end
    end

    def client
      @deploy_group.kubernetes_cluster.client
    end
  end
end
