# frozen_string_literal: true
class Admin::SecretsController < ApplicationController
  ADD_MORE = 'Save and add another'

  include CurrentProject

  before_action :find_project_permalinks
  before_action :find_secret, only: [:update, :show, :destroy]

  before_action :convert_visible_to_boolean, only: [:update, :create, :new]
  before_action :authorize_any_deployer!
  before_action :authorize_project_admin!, except: [:index, :new]

  def index
    @secret_keys = SecretStorage.keys.map { |key| [key, SecretStorage.parse_secret_key(key)] }
    @keys = @secret_keys.map { |_key, parts| parts.fetch(:key) }.uniq.sort
    if query = params.dig(:search, :query).presence
      @secret_keys.select! { |key, _parts| key.include?(query) }
    end
    [:key, :project_permalink].each do |part|
      if value = params.dig(:search, part).presence
        @secret_keys.select! { |_key, parts| parts.fetch(part) == value }
      end
    end
  rescue Samson::Secrets::BackendError => e
    flash[:error] = e.message
    render html: "", layout: true
  end

  def new
    render :show
  end

  def create
    if SecretStorage.exist?(key)
      failure_response "The secret #{key} already exists."
    else
      update
    end
  end

  def show
  end

  def update
    attributes = secret_params.slice(:value, :visible, :comment)
    attributes[:user_id] = current_user.id
    if SecretStorage.write(key, attributes)
      successful_response "Secret #{key} saved."
    else
      failure_response 'Failed to save.'
    end
  end

  def destroy
    SecretStorage.delete(key)
    if request.xhr?
      head :ok
    else
      successful_response "#{key} deleted"
    end
  end

  private

  def secret_params
    @secret_params ||= params.require(:secret).permit(*SecretStorage::SECRET_KEYS_PARTS, :value, :visible, :comment)
  end

  def key
    @key ||= (params[:id] || SecretStorage.generate_secret_key(secret_params.slice(*SecretStorage::SECRET_KEYS_PARTS)))
  end

  def project_permalink
    if params[:id].present?
      SecretStorage.parse_secret_key(params[:id]).fetch(:project_permalink)
    else
      secret_params.fetch(:project_permalink)
    end
  end

  def successful_response(notice)
    flash[:notice] = notice
    if params[:commit] == ADD_MORE
      redirect_to new_admin_secret_path(secret: params[:secret].except(:value).to_unsafe_h)
    else
      redirect_to action: :index
    end
  end

  def failure_response(message)
    flash[:error] = message
    render :show
  end

  def find_secret
    @secret = SecretStorage.read(key, include_value: true)
  end

  def find_project_permalinks
    @project_permalinks = SecretStorage.allowed_project_prefixes(current_user)
  end

  def current_project
    return if project_permalink == 'global'
    Project.find_by_permalink project_permalink
  end

  def authorize_any_deployer!
    return if current_user.deployer?
    return if current_user.user_project_roles.where('role_id >= ?', Role::DEPLOYER).exists?
    unauthorized!
  end

  # vault backend needs booleans and so does our view logic
  def convert_visible_to_boolean
    return unless secret = params[:secret]
    secret[:visible] = ActiveRecord::Type::Boolean.new.cast(secret[:visible])
  end
end
