# frozen_string_literal: true
class Admin::Kubernetes::ClustersController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [:create, :new, :update, :edit]

  before_action :find_cluster, only: [:show, :edit, :update]
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
    @clusters = ::Kubernetes::Cluster.all
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
end
