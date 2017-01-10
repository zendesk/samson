# frozen_string_literal: true
require 'kubeclient'

module Kubeclient
  class Client
    ClientMixin.resource_class(self, 'DeploymentRollback')

    # Entity methods for resources that have a / in their name are not defined by kubeclient
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

# Make our exceptions tell us what url/server/method they were triggered from
# https://github.com/abonas/kubeclient/pull/221
class KubeException < StandardError
  def to_s
    string = "HTTP status code #{@error_code} #{@message}"
    if @response.is_a?(RestClient::Response) && @response.request
      string += " for #{@response.request.method.upcase} #{@response.request.url}"
    end
    string
  end
end
