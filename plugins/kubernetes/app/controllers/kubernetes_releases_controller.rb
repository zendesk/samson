class KubernetesReleasesController < ApplicationController
  helper ProjectsHelper

  before_action :project
  before_action :authorize_deployer!

  def create
    @kuber_release_list = []

    deploy_groups.each do |deploy_group|
      params[:replicas].each do |role_name, replica_count|
        next if replica_count.blank?
        @kuber_release_list << KubernetesRelease.new(create_params.merge(deploy_group: deploy_group, role: role_name, replicas: replica_count, user: current_user))
      end
    end

    unless @kuber_release_list.map(&:valid?).all?
      binding.pry
      @kubernetes_release = @kuber_release_list.first
      render :new and return
    end

    @kuber_release_list.each do |release|
      release.save!
      KuberDeployService.new(release).deploy!
    end

    redirect_to [@project, @kuber_release_list.first]
  end

  def index
    @kuber_release_list = project.kubernetes_releases.order('id desc')
  end

  def new
    @environments = Environment.all
    @kubernetes_release = KubernetesRelease.new(user: current_user, build_id: params[:build_id])
  end

  def show
    @kubernetes_release = KubernetesRelease.find(params[:id])
  end

  def build
    @build = Build.find(params[:build_id])
    @kuber_release_list = @build.kubernetes_releases.order('id desc')
  end

  private

  def project
    @project ||= Project.find_by_param!(params[:project_id])
  end
  helper_method :project

  def new_params
    params.permit(:build_id)
  end

  def create_params
    params.require(:kubernetes_release).permit(:build_id)
  end

  def deploy_groups
    @deploy_groups ||= DeployGroup.where(id: params[:pods][:deploy_group_ids])
  end
end
