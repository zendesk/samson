class KubernetesReleaseGroupsController < ApplicationController
  include ProjectLevelAuthorization
  helper ProjectsHelper

  before_action :authorize_project_deployer!
  before_action :load_environments, only: [:new, :create]

  def index
    render json: current_project.kubernetes_release_groups.order('id desc'), root: false
  end

  def show
    @release_group = Kubernetes::ReleaseGroup.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render @release_group, root:false }
    end
  end

  def new
    @release_group = Kubernetes::ReleaseGroup.new(user: current_user, build_id: params[:build_id])

    respond_to do |format|
      format.html
      format.json {render @release_group, root:false }
    end
  end

  def create
    @release_group = Kubernetes::ReleaseGroup.new(create_params)
    @release_group.user = current_user

    @release_group.releases.each do |release|
      params[:replicas].each do |role_id, replica_count|
        release.release_docs.build(kubernetes_role_id: role_id, replica_target: replica_count.to_i)
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

  private

  def create_params
    params.require(:kubernetes_release_group).permit(:build_id, { deploy_group_ids: [] })
  end

  def load_environments
    @environments = Environment.all
  end
end
