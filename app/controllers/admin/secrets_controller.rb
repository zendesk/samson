class Admin::SecretsController < ApplicationController
  include CurrentProject

  before_action :find_project_permalinks
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
    if SecretStorage.write(key, value: value, user_id: current_user.id)
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
    @secret_params ||= params.require(:secret).permit(:project_permalink, :key, :value)
  end

  def key
    params[:id] || "#{secret_params.fetch(:project_permalink)}/#{secret_params.fetch(:key)}"
  end

  def project_permalink
    key.split('/', 2).first
  end

  def value
    secret_params.fetch(:value)
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

  def find_project_permalinks
    @project_permalinks = SecretStorage.allowed_project_prefixes(current_user)
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
