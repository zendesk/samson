class KubernetesReleasesController < ApplicationController
  helper ProjectsHelper

  before_action :project
  before_action :authorize_deployer!
  before_action :load_environments, only: [:new, :create]

  def index
    @kuber_release_list = project.kubernetes_releases.order('id desc')
  end

  def new
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

  def load_environments
    @environments = Environment.all
  end
end
