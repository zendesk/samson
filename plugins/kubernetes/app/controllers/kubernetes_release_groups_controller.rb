class KubernetesReleaseGroupsController < ApplicationController
  helper ProjectsHelper

  before_action :project
  before_action :authorize_deployer!
  before_action :load_environments, only: [:new, :create]

  def create
    @release_group = Kubernetes::ReleaseGroup.new(create_params)
    @release_group.user = current_user

    @release_group.releases.each do |release|
      params[:replicas].each do |role_id, replica_count|
        release.release_docs.build(kubernetes_role_id: role_id, replica_count: replica_count.to_i)
      end
    end

    unless @release_group.valid?
      render :new and return
    end

    @release_group.save!
    @release_group.releases.each do |release|
      KuberDeployService.new(release).deploy!
    end

    redirect_to project_kubernetes_release_group_path(@project, @release_group)
  end

  def index
    @release_group_list = project.kubernetes_release_groups.order('id desc')
  end

  def new
    @release_group = Kubernetes::ReleaseGroup.new(user: current_user, build_id: params[:build_id])
  end

  def show
    @release_group = Kubernetes::ReleaseGroup.find(params[:id])
  end

  def build
    @build = Build.find(params[:build_id])
    @release_group_list = @build.kubernetes_release_groups.order('id desc')
  end

  private

  def project
    @project ||= Project.find_by_param!(params[:project_id])
  end
  helper_method :project

  def create_params
    params.require(:kubernetes_release_group).permit(:build_id, { deploy_group_ids: [] })
  end

  def load_environments
    @environments = Environment.all
  end
end
