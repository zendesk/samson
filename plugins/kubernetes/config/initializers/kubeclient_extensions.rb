# frozen_string_literal: true
require 'kubeclient'

module Kubeclient
  class Client
    # Add Deployment and Daemonset waiting for PR:
    # https://github.com/abonas/kubeclient/pull/143
    NEW_ENTITY_TYPES = %w[Deployment DeploymentRollback DaemonSet Job].map do |et|
      clazz = Class.new(RecursiveOpenStruct) do
        def initialize(hash = nil, args = {})
          args[:recurse_over_arrays] = true
          super(hash, args)
        end
      end
      [Kubeclient.const_set(et, clazz), et]
    end
    ClientMixin.define_entity_methods(NEW_ENTITY_TYPES)
    ENTITY_TYPES.concat NEW_ENTITY_TYPES

    # Since Deployment isn't a supported model in the kubeclient gem, we need
    # to implement a custom method to handle the rollback endpoint.
    #
    # To roll back to a specific version of the deployment, you can pass in
    # the `:revision` option. If you pass in 0 (the default), it will roll
    # back to whatever the previous version was.
    def rollback_deployment(deployment_name, namespace = nil, revision: 0, annotations: nil)
      ns_prefix = build_namespace_prefix(namespace)

      # http://kubernetes.io/docs/api-reference/extensions/v1beta1/definitions/#_v1beta1_deploymentrollback
      hash = {
        kind: 'DeploymentRollback',
        apiVersion: @api_version,
        name: deployment_name,
        rollbackTo: {
          revision: revision
        }
      }
      hash[:updatedAnnotations] = annotations if annotations

      @headers['Content-Type'] = 'application/json'
      response = handle_exception do
        rest_client[ns_prefix + "deployments/#{deployment_name}/rollback"].
          post(hash.to_json, @headers)
      end
      new_entity(JSON.parse(response), DeploymentRollback)
    end
  end
end
