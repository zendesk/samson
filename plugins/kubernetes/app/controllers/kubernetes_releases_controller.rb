class KubernetesReleasesController < ApplicationController
  helper ProjectsHelper

  before_action :project
  before_action :authorize_deployer!

  # This create method actually creates 1+ Kubernetes::Release objects,
  # because it creates one for each DeployGroup the user wants to deploy to.
  def create
    @kuber_release_list = []

    # TODO: create a model that represents N releases
    selected_deploy_groups.each do |deploy_group|
      release = Kubernetes::Release.new(create_params.merge(deploy_group: deploy_group, user: current_user))

      params[:replicas].each do |role_id, replica_count|
        release.release_docs.build(kubernetes_role_id: role_id, replica_count: replica_count.to_i)
      end
      @kuber_release_list << release
    end

    # TODO: check for any role where replica_count == 0

    unless @kuber_release_list.map(&:valid?).all?
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
    @kubernetes_release = Kubernetes::Release.new(user: current_user, build_id: params[:build_id])
  end

  def show
    @kubernetes_release = Kubernetes::Release.find(params[:id])
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

  def selected_deploy_groups
    @selected_deploy_groups ||= DeployGroup.where(id: params[:pods][:deploy_group_ids])
  end
end
