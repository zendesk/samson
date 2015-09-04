class KubernetesClustersController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :create, :new, :update ]

  before_action :find_cluster, only: [:show, :edit, :update]
  before_action :load_environments, only: [:new, :edit, :update]

  def new
    @cluster = Kubernetes::Cluster.new(api_version: 'v1')
  end

  def create
    @cluster = Kubernetes::Cluster.new(new_cluster_params)
    @cluster.save

    respond_to do |format|
      format.html do
        if @cluster.persisted?
          redirect_to kubernetes_clusters_path(@cluster)
        else
          render :new, status: 422
        end
      end

      format.json do
        render json: {}, status: @cluster.persisted? ? 200 : 422
      end
    end
  end

  def index
    @cluster_list = Kubernetes::Cluster.all
  end

  def show
  end

  def edit
  end

  def update
    @cluster.assign_attributes(new_cluster_params)
    success = @cluster.save

    respond_to do |format|
      format.html do
        if success
          redirect_to kubernetes_clusters_path
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
    @cluster = Kubernetes::Cluster.find(params[:id])
  end

  def load_environments
    @environments = Environment.includes(:deploy_groups).all
  end

  def new_cluster_params
    params.require(:kubernetes_cluster).permit(:name, :username, :url, :use_ssl, :api_version, :description, { deploy_group_ids: [] })
  end
end
