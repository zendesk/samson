# frozen_string_literal: true

class ExternalSetupHooksController < ApplicationController
  before_action :authorize_user!, except: [:index, :show]
  before_action :hook, only: [:show]

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
    hook.attributes = attributes
    hook.save!
    redirect_to action: :index
  end

  def show
    render 'form'
  end

  def update
    hook.update_attributes!(attributes)
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

  def attributes
    params.require(:external_setup_hook).permit(*[
      :name,
      :description,
      :endpoint,
      :auth_type,
      :auth_token,
      :verify_ssl
    ])
  end

  def authorize_user!
    # unauthorized! unless can? :write, :environment_variable_groups, hook
    hook
  end
end
