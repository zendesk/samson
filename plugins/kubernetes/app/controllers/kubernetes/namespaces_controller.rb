# frozen_string_literal: true
class Kubernetes::NamespacesController < ResourceController
  before_action :authorize_admin!, except: [:show, :index]
  before_action :set_resource, only: [:show, :update, :destroy, :new, :create]

  private

  def create_callback
    errors = Kubernetes::Cluster.all.map do |cluster|
      begin
        client = cluster.client('v1')
        annotations = {"samson/url": kubernetes_namespace_url(@kubernetes_namespace)}

        begin
          SamsonKubernetes.retry_on_connection_errors { client.get_namespace(@kubernetes_namespace.name) }
        rescue Kubeclient::ResourceNotFoundError
          nil # did not exist, let's create it
        else
          SamsonKubernetes.retry_on_connection_errors do
            client.patch_namespace(@kubernetes_namespace.name, metadata: {annotations: annotations})
          end
          next "Namespace already exists in cluster #{cluster.name}"
        end

        namespace_manifest = {
          metadata: {
            name: @kubernetes_namespace.name,
            annotations: annotations
          }
        }
        SamsonKubernetes.retry_on_connection_errors { client.create_namespace(namespace_manifest) }
        nil
      rescue StandardError => e
        "Failed to create namespace in cluster #{cluster.name}: #{e.message}"
      end
    end.compact

    if errors.any?
      flash[:alert] = helpers.simple_format("Error creating namespace in some clusters:\n" + errors.join("\n"))
    end
  end

  def resource_params
    permitted = [:comment, {project_ids: []}]
    permitted << :name if ["new", "create"].include?(action_name)
    super.permit(*permitted)
  end
end
