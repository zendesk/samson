# frozen_string_literal: true
class Admin::VaultServersController < ApplicationController
  before_action :authorize_super_admin!, except: [:index, :show]
  before_action :find_server, only: [:update, :show, :destroy, :sync]

  def index
    @vault_servers = Samson::Secrets::VaultServer.all
  end

  def new
    @vault_server = Samson::Secrets::VaultServer.new
    render :show
  end

  def show
  end

  def create
    @vault_server = Samson::Secrets::VaultServer.new(server_params)
    if @vault_server.save
      redirect_to({action: :index}, notice: "Created")
    else
      render :show
    end
  end

  def sync
    updated = @vault_server.sync!(Samson::Secrets::VaultServer.find(params.require(:other_id))).count
    redirect_to({action: :show}, notice: "Synced #{updated} values!")
  end

  def update
    if @vault_server.update_attributes(server_params)
      redirect_to({action: :index}, notice: "Updated")
    else
      render :show
    end
  end

  def destroy
    @vault_server.destroy!
    redirect_to({action: :index}, notice: "Deleted #{@vault_server.name} ##{@vault_server.id}")
  end

  private

  def server_params
    params.require(:vault_server).permit(:name, :address, :token, :ca_cert, :tls_verify)
  end

  def find_server
    @vault_server = Samson::Secrets::VaultServer.find(params.require(:id))
  end
end
