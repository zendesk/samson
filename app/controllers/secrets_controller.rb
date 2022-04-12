# frozen_string_literal: true
class SecretsController < ApplicationController
  UPDATEDABLE_ATTRIBUTES = [:value, :visible, :deprecated_at, :comment].freeze

  include CurrentProject

  before_action :find_writable_project_permalinks, only: [:new, :create, :show, :update]
  before_action :find_secret, only: [:update, :show]

  before_action :normalize_params_for_backend, only: [:update, :create, :new]
  before_action :authorize_resource!

  def index
    @secrets = Samson::Secrets::Manager.lookup_cache.map do |id, secret_stub|
      [id, Samson::Secrets::Manager.parse_id(id), secret_stub]
    end

    @project_permalinks =
      @secrets.map { |_, parts, _| parts.fetch(:project_permalink) }.uniq.sort - ['global'] + ['global']
    @deploy_group_permalinks =
      @secrets.map { |_, parts, _| parts.fetch(:deploy_group_permalink) }.uniq.sort - ['global'] + ['global']
    @environment_permalinks =
      @secrets.map { |_, parts, _| parts.fetch(:environment_permalink) }.uniq.sort - ['global'] + ['global']
    @keys = @secrets.map { |_, parts, _| parts.fetch(:key) }.uniq.sort

    Samson::Secrets::Manager::ID_PARTS.each do |part|
      if value = params.dig(:search, part).presence
        @secrets.select! { |_, parts, _| parts.fetch(part) == value }
      end
    end

    if value_hashed = params.dig(:search, :value_hashed).presence
      @secrets.select! { |_, _, secret_stub| secret_stub[:value_hashed] == value_hashed }
    end

    if value_from = params.dig(:search, :value_from).presence
      value = Samson::Secrets::Manager.read(value_from, include_value: true).fetch(:value)
      matching = Samson::Secrets::Manager.filter_ids_by_value(@secrets.map(&:first), value)
      matching.delete(value_from) # do not show what we already know
      @secrets.select! { |id, _, _| matching.include?(id) }
    end
    @pagy, @secrets = pagy_array(@secrets, page: params[:page], items: 50)

    respond_to do |format|
      format.html
      format.json do
        render_as_json :secrets, @secrets, @pagy
      end
    end
  rescue Samson::Secrets::BackendError => e
    flash[:alert] = e.message
    render html: "", layout: true
  end

  def duplicates
    @groups = Samson::Secrets::Manager.lookup_cache.
      group_by { |_, v| v.fetch(:value_hashed) }.
      select { |_, v| v.size >= 2 }.
      sort_by { |_, v| -v.size }
  end

  def resolve
    if params[:project_id].present?
      project = Project.find(params[:project_id])
    elsif params[:project_permalink].present?
      project = Project.find_by_permalink!(params[:project_permalink])
    else
      render_json_error 400, "Neither project_id or project_permalink given as parameters"
      return
    end

    deploy_group = DeployGroup.find_by_permalink!(params.require(:deploy_group))
    keys_param = params.require(:keys)
    keys = keys_param.is_a?(Array) ? keys_param : keys_param.split(/, ?/)

    resolver = Samson::Secrets::KeyResolver.new(project, [deploy_group])

    resolved = {}
    keys.each do |key|
      expanded = resolver.expand(key, key)
      if expanded.any?
        expanded.each { |k, r| resolved[k] = r }
      else
        resolved[key] = nil
      end
    end

    respond_to do |format|
      format.json do
        render json: {resolved: resolved}
      end
    end
  end

  def history
    @history = Samson::Secrets::Manager.history(id, resolve: true)
  end

  def revert
    version = params.require(:version)
    Samson::Secrets::Manager.revert(id, to: version, user: current_user)
    redirect_to secret_path(id), notice: "Reverted to #{version}!"
  end

  def new
    render :show
  end

  def create
    if Samson::Secrets::Manager.exist?(id)
      failure_response "The secret #{id} already exists."
    else
      update
    end
  end

  def show
    respond_to do |format|
      format.html do
        render :show
      end

      format.json do
        render json: {secret: @secret}
      end
    end
  end

  def update
    attributes = secret_params.slice(*UPDATEDABLE_ATTRIBUTES)

    # allow updating comments by backfilling value ... but not making visible
    if attributes[:value].blank?
      old = Samson::Secrets::Manager.read(id, include_value: true)
      if old[:visible] || attributes[:visible]
        failure_response 'Cannot update visibility without value.'
        return
      else
        attributes[:value] = old.fetch(:value)
      end
    elsif secret_params[:allow_duplicates] != '1'
      duplicates = Samson::Secrets::Manager.filter_ids_by_value(
        Samson::Secrets::Manager.lookup_cache.keys - [id],
        attributes.fetch(:value)
      )

      if duplicates.any?
        @duplicate_secret_error = true
        failure_response "Secret #{duplicates.join(', ')} already use the same value, reuse them as global secrets"
        return
      end
    end

    attributes[:user_id] = current_user.id

    if Samson::Secrets::Manager.write(id, attributes)
      @secret = Samson::Secrets::Manager.read(id, include_value: true)
      @secret[:value] = nil unless @secret.fetch(:visible)
      successful_response "Secret #{id} saved."
    else
      failure_response 'Failed to save.'
    end
  end

  def destroy
    Samson::Secrets::Manager.delete(id)
    if request.xhr?
      head :ok
    else
      successful_response "#{id} deleted"
    end
  end

  private

  def secret_params
    @secret_params ||= begin
      sent = params.require(:secret).permit(
        *Samson::Secrets::Manager::ID_PARTS,
        *UPDATEDABLE_ATTRIBUTES,
        :allow_duplicates
      )
      sent[:value] = sent[:value].gsub("\r\n", "\n") if sent[:value]
      sent
    end
  end

  def id
    @id ||= params[:id] ||
      Samson::Secrets::Manager.generate_id(secret_params.slice(*Samson::Secrets::Manager::ID_PARTS))
  end

  def project_permalink
    if params[:id].present?
      Samson::Secrets::Manager.parse_id(params[:id]).fetch(:project_permalink)
    else
      (params[:secret] && params[:secret][:project_permalink]) || 'global'
    end
  end

  def successful_response(notice)
    respond_to do |format|
      format.html do
        flash[:notice] = notice
        if params[:commit] == ResourceController::ADD_MORE
          redirect_to new_secret_path(secret: params[:secret].except(:value).to_unsafe_h)
        else
          redirect_to action: :index
        end
      end
      format.json do
        render json: {secret: @secret}
      end
    end
  end

  def failure_response(message)
    respond_to do |format|
      format.html do
        flash[:alert] = message
        render :show
      end
      format.json do
        render json: {error: message}, status: :bad_request
      end
    end
  end

  def find_secret
    @secret = Samson::Secrets::Manager.read(id, include_value: true)
    @secret[:value] = nil unless @secret.fetch(:visible)
  end

  def find_writable_project_permalinks
    @writable_project_permalinks = Samson::Secrets::Manager.allowed_project_prefixes(current_user)
  end

  def require_project
    permalink = project_permalink
    return if permalink == 'global'
    @project = Project.find_by_permalink permalink
  end

  def normalize_params_for_backend
    return unless secret = params[:secret]

    # vault backend needs booleans and so does our view logic
    secret[:visible] = truthy?(secret[:visible])

    # vault should not store unchecked box "0" as deprecated_at
    secret[:deprecated_at] = nil unless truthy?(secret[:deprecated_at])
  end

  def truthy?(value)
    ActiveRecord::Type::Boolean.new.cast(value)
  end

  # @override CurrentUser since we need to allow any user to see new since we do not yet
  # know what project they want to create for
  def resource_action
    ["new", "duplicates", "history"].include?(action_name) ? :read : super
  end
end
