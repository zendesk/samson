# frozen_string_literal: true
class Admin::Kubernetes::ClustersController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, except: [:index, :show, :seed_ecr]

  before_action :find_cluster, only: [:show, :edit, :update, :seed_ecr]
  before_action :load_default_config_file, only: [:new, :edit, :update, :create]

  def new
    @cluster = ::Kubernetes::Cluster.new(config_filepath: @config_file)
    render :edit
  end

  def create
    @cluster = ::Kubernetes::Cluster.new(new_cluster_params)
    if @cluster.save
      redirect_to [:admin, @cluster], notice: "Saved!"
    else
      render :edit
    end
  end

  def index
    @clusters = ::Kubernetes::Cluster.all.sort_by { |c| Samson::NaturalOrder.convert(c.name) }
  end

  def show
  end

  def edit
  end

  def update
    @cluster.assign_attributes(new_cluster_params)
    if @cluster.save
      redirect_to({action: :index}, notice: "Saved!")
    else
      render :edit
    end
  end

  def seed_ecr
    SamsonAwsEcr::Engine.refresh_credentials
    @cluster.namespaces.each do |namespace|
      update_secret namespace
    end
    redirect_to({action: :index}, notice: "Seeded!")
  end

  private

  def find_cluster
    @cluster = ::Kubernetes::Cluster.find(params[:id])
  end

  def new_cluster_params
    params.require(:kubernetes_cluster).permit(
      :name, :config_filepath, :config_context, :description, :ip_prefix, deploy_group_ids: []
    )
  end

  def load_default_config_file
    @config_file = if @cluster
      @cluster.config_filepath
    elsif file = ENV['KUBE_CONFIG_FILE']
      File.expand_path(file)
    elsif last_cluster = ::Kubernetes::Cluster.last
      last_cluster.config_filepath
    end

    @context_options = Kubeclient::Config.read(@config_file).contexts if @config_file
    @context_options ||= []
  end

  # same as this does under the hood:
  # http://kubernetes.io/docs/user-guide/images/#using-aws-ec2-container-registry
  # kubectl create secret docker-registry kube-ecr-auth --docker-server=X --docker-username=X --docker-password=X
  def update_secret(namespace)
    docker_config = DockerRegistry.all.each_with_object({}) do |r, h|
      h[r.host] = { username: r.username, password: r.password }
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
      @cluster.client.update_secret(secret)
    else
      @cluster.client.create_secret(secret)
    end
  end

  def secret_exist?(secret)
    @cluster.client.get_secret(secret.fetch(:metadata).fetch(:name), secret.fetch(:metadata).fetch(:namespace))
    true
  rescue KubeException
    false
  end
end
