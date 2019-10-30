# frozen_string_literal: true
class Kubernetes::NamespacesController < ResourceController
  before_action :authorize_admin!, except: [:show, :index]
  before_action :set_resource, only: [:show, :update, :destroy, :new, :create, :sync]

  def update
    super
    sync_namespace if @kubernetes_namespace.previous_changes.key?(:template)
  end

  def sync_all
    clusters = Kubernetes::Cluster.all.to_a
    errors = Samson::Parallelizer.map(Kubernetes::Namespace.all.to_a) do |namespace|
      upsert_namespace clusters, namespace
    end.flatten(1)
    show_namespace_errors errors
    redirect_to action: :index
  end

  def sync
    sync_namespace
    redirect_to @kubernetes_namespace
  end

  private

  def create_callback
    sync_namespace
  end

  def sync_namespace
    errors = upsert_namespace Kubernetes::Cluster.all, @kubernetes_namespace
    show_namespace_errors errors
  end

  # @return [Array<String>] errors
  def upsert_namespace(clusters, namespace)
    clusters.map do |cluster|
      begin
        client = cluster.client('v1')

        begin
          SamsonKubernetes.retry_on_connection_errors { client.get_namespace(namespace.name) }
        rescue Kubeclient::ResourceNotFoundError
          SamsonKubernetes.retry_on_connection_errors { client.create_namespace(namespace.manifest) }
        else
          # add configuration, but do not override labels/annotations set by other tools
          SamsonKubernetes.retry_on_connection_errors { client.patch_namespace(namespace.name, namespace.manifest) }
        end
        nil
      rescue StandardError => e
        "Failed to upsert namespace #{namespace.name} in cluster #{cluster.name}: #{e.message}"
      end
    end.compact
  end

  def show_namespace_errors(errors)
    return if errors.empty?
    flash[:alert] = helpers.simple_format("Error upserting namespace in some clusters:\n" + errors.join("\n"))
  end

  def resource_params
    permitted = [:comment, :template, {project_ids: []}]
    permitted << :name if ["new", "create"].include?(action_name)
    super.permit(*permitted)
  end
end
