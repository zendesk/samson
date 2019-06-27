# frozen_string_literal: true
class SecretSharingGrantsController < ApplicationController
  before_action :authorize_admin!, except: [:index, :show]
  before_action :find_grant, only: [:show, :destroy]

  def index
    query = params[:search]&.to_unsafe_h&.slice(:key, :project_id)&.select { |_, v| v.present? }
    @pagy, @secret_sharing_grants = pagy(SecretSharingGrant.where(query).order(:key), page: params[:page], items: 25)
  end

  def new
    @secret_sharing_grant = SecretSharingGrant.new(key: params.dig(:secret_sharing_grant, :key))
  end

  def create
    attributes = params.require(:secret_sharing_grant).permit(:key, :project_id)
    @secret_sharing_grant = SecretSharingGrant.create(attributes)
    if @secret_sharing_grant.persisted?
      redirect_back fallback_location: @secret_sharing_grant, notice: 'Grant created'
    else
      render :new
    end
  end

  def show
  end

  def destroy
    @secret_sharing_grant.destroy
    redirect_to secret_sharing_grants_path, notice: 'Grant revoked'
  end

  private

  def find_grant
    @secret_sharing_grant = SecretSharingGrant.find(params.require(:id))
  end
end
