# frozen_string_literal: true
class Kubernetes::ClustersController < ResourceController
  PUBLIC = [:index, :show].freeze
  HIDDEN = "-- hidden --"
  before_action :authorize_admin!, except: PUBLIC
  before_action :authorize_super_admin!, except: PUBLIC + [:seed_ecr]
  before_action :set_resource, only: [:show, :edit, :update, :destroy, :seed_ecr, :new, :create]

  def new
    super
    @kubernetes_cluster.config_filepath ||= new_config_filepath
  end

  def index
    @kubernetes_clusters = ::Kubernetes::Cluster.all.sort_by { |c| Samson::NaturalOrder.convert(c.name) }

    respond_to do |format|
      format.html do
        if params[:capacity]
          @cluster_nodes = Samson::Parallelizer.map(@kubernetes_clusters) do |cluster|
            [cluster.id, cluster.schedulable_nodes]
          end.to_h
        end
      end
      format.json do
        render_as_json(
          :kubernetes_clusters,
          @kubernetes_clusters,
          nil,
          allowed_includes: [:deploy_groups]
        )
      end
    end
  end

  def seed_ecr
    SamsonAwsEcr::SamsonPlugin.refresh_credentials
    @kubernetes_cluster.namespaces.each do |namespace|
      update_secret namespace
    end
    redirect_to({action: :index}, notice: "Seeded!")
  end

  def edit
    @kubernetes_cluster.client_cert = HIDDEN if @kubernetes_cluster.client_cert?
    @kubernetes_cluster.client_key = HIDDEN if @kubernetes_cluster.client_key?
    super
  end

  private

  def resource_params
    params = super.permit(
      :name, :config_filepath, :config_context, :description,
      :auth_method, :api_endpoint, :verify_ssl, :client_cert, :client_key,
      :kritis_breakglass,
      deploy_group_ids: []
    )
    params.delete_if { |_, v| v == HIDDEN }
    params
  end

  def new_config_filepath
    if file = ENV['KUBE_CONFIG_FILE']
      File.expand_path(file)
    else
      ::Kubernetes::Cluster.last&.config_filepath
    end
  end

  # same as this does under the hood:
  # http://kubernetes.io/docs/user-guide/images/#using-aws-ec2-container-registry
  # kubectl create secret docker-registry kube-ecr-auth --docker-server=X --docker-username=X --docker-password=X
  def update_secret(namespace)
    docker_config = DockerRegistry.all.each_with_object({}) do |r, h|
      h[r.host] = {username: r.username, password: r.password}
    end

    secret = {
      kind: "Secret",
      apiVersion: "v1",
      metadata: {
        name: "kube-ecr-auth",
        namespace: namespace,
        annotations: {
          via: "Samson",
          created_at: Time.now.to_s(:db)
        }
      },
      data: {
        ".dockercfg" => Base64.encode64(JSON.dump(docker_config))
      },
      type: "kubernetes.io/dockercfg"
    }

    if secret_exist?(secret)
      secrets_client.update_secret(secret)
    else
      secrets_client.create_secret(secret)
    end
  end

  def secret_exist?(secret)
    secrets_client.get_secret(secret.fetch(:metadata).fetch(:name), secret.fetch(:metadata).fetch(:namespace))
    true
  rescue *SamsonKubernetes.connection_errors
    false
  end

  def secrets_client
    @kubernetes_cluster.client('v1')
  end
end
