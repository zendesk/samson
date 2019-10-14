# frozen_string_literal: true

class ExternalSetupHooksController < ApplicationController
  before_action :authorize_user!, except: [:index, :show, :preview]
  # before_action :group, only: [:show]

  def index
    @hooks = ExternalSetupHook.all
    respond_to do |format|
      format.html
    end
  end

  def new
    render 'form'
  end

  def create
    allowed = [:name, :description, :endpoint, :auth_type, :auth_token]
    hook.attributes = params.require(:external_setup_hook).permit(*allowed)
    hook.save!
    redirect_to action: :index
  end

  def destroy
    hook.destroy!
    redirect_to action: :index
  end

  private

  def hook
    @hook ||= if ['new', 'create'].include?(action_name)
      ExternalSetupHook.new
    else
      ExternalSetupHook.find(params[:id])
    end
  end

  def authorize_user!
    # unauthorized! unless can? :write, :environment_variable_groups, hook
    hook
  end
end
