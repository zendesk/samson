# frozen_string_literal: true
class SecretsController < ApplicationController
  ADD_MORE = 'Save and add another'

  include CurrentProject

  before_action :find_project_permalinks
  before_action :find_secret, only: [:update, :show]

  before_action :convert_visible_to_boolean, only: [:update, :create, :new]
  before_action :authorize_resource!

  def index
    @secret_ids = SecretStorage.ids.map { |id| [id, SecretStorage.parse_id(id)] }
    @keys = @secret_ids.map { |_key, parts| parts.fetch(:key) }.uniq.sort

    SecretStorage::ID_PARTS.each do |part|
      if value = params.dig(:search, part).presence
        @secret_ids.select! { |_key, parts| parts.fetch(part) == value }
      end
    end

    if value = params.dig(:search, :value).presence
      matching = SecretStorage.filter_ids_by_value(@secret_ids.map(&:first), value)
      @secret_ids.select! { |key, _parts| matching.include?(key) }
    end
  rescue Samson::Secrets::BackendError => e
    flash[:error] = e.message
    render html: "", layout: true
  end

  def new
    render :show
  end

  def create
    if SecretStorage.exist?(id)
      failure_response "The secret #{id} already exists."
    else
      update
    end
  end

  def show
  end

  def update
    attributes = secret_params.slice(:value, :visible, :comment)
    attributes[:user_id] = current_user.id
    if SecretStorage.write(id, attributes)
      successful_response "Secret #{id} saved."
    else
      failure_response 'Failed to save.'
    end
  end

  def destroy
    SecretStorage.delete(id)
    if request.xhr?
      head :ok
    else
      successful_response "#{id} deleted"
    end
  end

  private

  def secret_params
    @secret_params ||= params.require(:secret).permit(*SecretStorage::ID_PARTS, :value, :visible, :comment)
  end

  def id
    @id ||= (params[:id] || SecretStorage.generate_id(secret_params.slice(*SecretStorage::ID_PARTS)))
  end

  def project_permalink
    if params[:id].present?
      SecretStorage.parse_id(params[:id]).fetch(:project_permalink)
    else
      (params[:secret] && params[:secret][:project_permalink]) || 'global'
    end
  end

  def successful_response(notice)
    flash[:notice] = notice
    if params[:commit] == ADD_MORE
      redirect_to new_secret_path(secret: params[:secret].except(:value).to_unsafe_h)
    else
      redirect_to action: :index
    end
  end

  def failure_response(message)
    flash[:error] = message
    render :show
  end

  def find_secret
    @secret = SecretStorage.read(id, include_value: true)
    @secret[:value] = nil unless @secret.fetch(:visible)
  end

  def find_project_permalinks
    @project_permalinks = SecretStorage.allowed_project_prefixes(current_user)
  end

  def require_project
    permalink = project_permalink
    return if permalink == 'global'
    @project = Project.find_by_permalink permalink
  end

  # vault backend needs booleans and so does our view logic
  def convert_visible_to_boolean
    return unless secret = params[:secret]
    secret[:visible] = ActiveRecord::Type::Boolean.new.cast(secret[:visible])
  end

  # @override CurrentUser since we need to allow any user to see new since we do not yet
  # know what project they want to create for
  def resource_action
    action_name == "new" ? :read : super
  end
end
