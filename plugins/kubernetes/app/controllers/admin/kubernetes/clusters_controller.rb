class Admin::Kubernetes::ClustersController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [:create, :new, :update, :edit]

  before_action :find_cluster, only: [:show, :edit, :update]
  before_action :load_default_config_file, only: [:new, :edit, :update, :create]

  def new
    @cluster = ::Kubernetes::Cluster.new(config_filepath: @config_file)
  end

  def create
    @cluster = ::Kubernetes::Cluster.new(new_cluster_params)
    success = @cluster.save
    @cluster.watch! if success

    respond_to do |format|
      format.html do
        if success
          redirect_to admin_kubernetes_cluster_path(@cluster)
        else
          render :new, status: 422
        end
      end

      format.json do
        render json: {}, status: success ? 200 : 422
      end
    end
  end

  def index
    @clusters = ::Kubernetes::Cluster.all
  end

  def show
  end

  def edit
  end

  def update
    @cluster.assign_attributes(new_cluster_params)
    success = @cluster.save
    @cluster.watch! if success

    respond_to do |format|
      format.html do
        if success
          redirect_to admin_kubernetes_clusters_path
        else
          render :edit, status: 422
        end
      end

      format.json do
        render json: {}, status: success ? 200 : 422
      end
    end
  end

  private

  def find_cluster
    @cluster = ::Kubernetes::Cluster.find(params[:id])
  end

  def new_cluster_params
    params.require(:kubernetes_cluster).permit(
      :name, :config_filepath, :config_context, :description, deploy_group_ids: []
    )
  end

  def load_default_config_file
    if (file = ENV['KUBE_CONFIG_FILE'])
      @config_file = file
    elsif (last_cluster = ::Kubernetes::Cluster.last)
      @config_file = last_cluster.config_filepath
    end

    @context_options = Kubeclient::Config.read(@config_file).contexts if @config_file
    @context_options ||= []
  end
end
