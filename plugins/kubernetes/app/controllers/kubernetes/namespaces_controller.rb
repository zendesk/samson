# frozen_string_literal: true
class Kubernetes::NamespacesController < ResourceController
  before_action :authorize_admin!, except: [:show, :index]
  before_action :set_resource, only: [:show, :update, :destroy, :new, :create, :sync]

  def sync_all
    clusters = Kubernetes::Cluster.all.to_a
    errors = Samson::Parallelizer.map(Kubernetes::Namespace.all.to_a) do |namespace|
      create_namespace clusters, namespace
    end.flatten(1)
    show_namespace_errors errors
    redirect_to action: :index
  end

  def sync
    create_callback
    redirect_to @kubernetes_namespace
  end

  private

  def create_callback
    errors = create_namespace Kubernetes::Cluster.all, @kubernetes_namespace
    show_namespace_errors errors
  end

  def create_namespace(clusters, namespace)
    clusters.map do |cluster|
      begin
        client = cluster.client('v1')
        annotations = {"samson/url": kubernetes_namespace_url(namespace)}

        begin
          SamsonKubernetes.retry_on_connection_errors { client.get_namespace(namespace.name) }
        rescue Kubeclient::ResourceNotFoundError
          nil # did not exist, let's create it
        else
          SamsonKubernetes.retry_on_connection_errors do
            client.patch_namespace(namespace.name, metadata: {annotations: annotations})
          end
          next # all good
        end

        namespace_manifest = {
          metadata: {
            name: namespace.name,
            annotations: annotations
          }
        }
        SamsonKubernetes.retry_on_connection_errors { client.create_namespace(namespace_manifest) }
        nil
      rescue StandardError => e
        "Failed to create namespace #{namespace.name} in cluster #{cluster.name}: #{e.message}"
      end
    end.compact
  end

  def show_namespace_errors(errors)
    return if errors.empty?
    flash[:alert] = helpers.simple_format("Error upserting namespace in some clusters:\n" + errors.join("\n"))
  end

  def resource_params
    permitted = [:comment, {project_ids: []}]
    permitted << :name if ["new", "create"].include?(action_name)
    super.permit(*permitted)
  end
end
