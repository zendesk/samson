class Admin::SecretsController < ApplicationController
  include CurrentProject

  before_action :find_project_permalinks, :find_environments_permalinks, :generate_deploy_group_list, :find_deploy_group_permalinks
  before_action :find_secret, only: [:update, :edit, :destroy]

  DEPLOYER_ACCESS = [:index, :new]
  before_action :ensure_project_access, except: DEPLOYER_ACCESS
  before_action :authorize_project_admin!, except: DEPLOYER_ACCESS
  before_action :authorize_deployer!, only: DEPLOYER_ACCESS

  def index
    @secret_keys = SecretStorage.keys
  end

  def new
    render :edit
  end

  def create
    update
  end

  def update
    attributes = {
      user_id: current_user.id,
      value:  value
    }
    attributes[:environment_permalink] = environment_permalink if environment_permalink
    attributes[:project_permalink] = project_permalink if project_permalink
    attributes[:deploy_group_permalink] = deploy_group_permalink if deploy_group_permalink
    #if SecretStorage.write(key, value: value, user_id: current_user.id, deploy_group_permalink: deploy_group_permalink, environment_permalink: environment_permalink, project_permalink: project_permalink)
    if SecretStorage.write(key, attributes)
      successful_response 'Secret created.'
    else
      failure_response 'Failed to save.'
    end
  end

  def destroy
    SecretStorage.delete(key)
    successful_response('Secret removed.')
  end

  private

  def secret_params
    @secret_params ||= params.require(:secret).permit(:project_permalink, :deploy_group_permalink, :environment_permalink, :key, :value)
  end

  def key
    params[:id] || "#{secret_params.fetch(:environment_permalink)}/#{secret_params.fetch(:project_permalink)}/#{secret_params.fetch(:deploy_group_permalink)}/#{secret_params.fetch(:key)}"
  end

  def project_permalink
    params[:id].present? ? params[:id].split('/', 4).second : secret_params.fetch(:project_permalink)
  end

  def value
    secret_params.fetch(:value)
  end

  def deploy_group_permalink
    params[:id].present? ? params[:id].split('/', 4).third : secret_params.fetch(:deploy_group_permalink)
  end

  def environment_permalink
    params[:id].present? ? params[:id].split('/', 4).first : secret_params.fetch(:environment_permalink, false)
  end

  def successful_response(notice)
    flash[:notice] = notice
    redirect_to action: :index
  end

  def failure_response(message)
    flash[:error] = message
    render :edit
  end

  def find_secret
    @secret = SecretStorage.read(key)
  end

  def generate_deploy_group_list
    @deployment_group_list = []
    DeployGroup.all.map do |group|
      @deployment_group_list << { "#{group.environment.permalink}": group.permalink }
    end
    @deployment_group_list
  end

  def find_project_permalinks
    @project_permalinks = SecretStorage.allowed_project_prefixes(current_user)
  end

  def find_environments_permalinks
    @environment_permalinks = Environment.all().pluck(:permalink)
  end

  def find_deploy_group_permalinks
    @deploy_group_permalinks = DeployGroup.all().pluck(:permalink)
  end

  def ensure_project_access
    return if current_user.admin?
    unauthorized! unless @project_permalinks.include?(project_permalink)
  end

  def current_project
    return if project_permalink == 'global'
    Project.find_by_permalink project_permalink
  end
end
