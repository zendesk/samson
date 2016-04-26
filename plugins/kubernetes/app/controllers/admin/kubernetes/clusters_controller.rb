class Admin::Kubernetes::ClustersController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :create, :new, :update, :edit ]

  before_action :find_cluster, only: [:show, :edit, :update]
  before_action :load_default_config_file, only: [:new, :edit, :update]

  def new
    @cluster = ::Kubernetes::Cluster.new(config_filepath: @config_file.try(:filepath))
  end

  def create
    @cluster = ::Kubernetes::Cluster.new(new_cluster_params)
    success = @cluster.save
    @cluster.watch! if success

    respond_to do |format|
      format.html do
        if success
          redirect_to admin_kubernetes_clusters_path(@cluster)
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
    params.require(:kubernetes_cluster).permit(:name, :config_filepath, :config_context, :description, { deploy_group_ids: [] })
  end

  def load_default_config_file
    var = 'KUBE_CONFIG_FILE'
    if (file = ENV[var])
      @config_file = ::Kubernetes::ClientConfigFile.new(file)
      @context_options = @config_file.context_names
    else
      render text: "#{var} is not configured, for local development it should be ~/.kube/config", status: :bad_request
    end
  end
end
