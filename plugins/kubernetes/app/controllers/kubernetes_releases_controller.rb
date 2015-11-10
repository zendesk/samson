class KubernetesReleasesController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_project_deployer!
  before_action :load_environments, only: [:new, :create]

  def index
    render json: current_project.kubernetes_releases.order('id desc'), root: false
  end

  def show
    @release = Kubernetes::Release.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render @release, root:false }
    end
  end

  def new
    @release = Kubernetes::Release.new(user: current_user, build_id: params[:build_id])

    respond_to do |format|
      format.html
      format.json {render @release, root:false }
    end
  end

  def create
    @release = Kubernetes::Release.create(create_params)
    @release.user = current_user

    deploy_group_ids = params[:kubernetes_release][:deploy_group_ids].select(&:presence)
    DeployGroup.find(deploy_group_ids).each do |deploy_group|
      params[:replicas].each do |role_id, replica_count|
        @release.release_docs.create(kubernetes_role_id: role_id, replica_target: replica_count.to_i, deploy_group: deploy_group)
      end
    end

    unless @release.valid?
      render :new and return
    end

    @release.save!
    KuberDeployService.new(@release).deploy!

    redirect_to project_kubernetes_release_path(current_project, @release)
  end

  private

  def create_params
    params.require(:kubernetes_release).permit(:build_id, { deploy_group_ids: [] })
  end

  def load_environments
    @environments = Environment.all
  end
end
