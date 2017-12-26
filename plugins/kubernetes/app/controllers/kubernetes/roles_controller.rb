# frozen_string_literal: true
class Kubernetes::RolesController < ApplicationController
  include CurrentProject

  DEFAULT_BRANCH = 'master'

  PUBLIC = [:index, :show, :example].freeze
  before_action :authorize_project_deployer!, except: PUBLIC
  before_action :authorize_project_admin!, except: PUBLIC
  before_action :find_role, only: [:show, :update, :destroy]

  def index
    @roles = ::Kubernetes::Role.not_deleted.where(project: current_project).order(:name).to_a
    respond_to do |format|
      format.html
      format.json { render json: @roles.as_json }
    end
  end

  def seed
    begin
      Kubernetes::Role.seed!(@project, params[:ref].presence || DEFAULT_BRANCH)
    rescue Samson::Hooks::UserError
      flash[:error] = $!.message
    end
    redirect_to action: :index
  end

  def example
  end

  def new
    @role = Kubernetes::Role.new
  end

  def create
    @role = Kubernetes::Role.new(role_params.merge(project: @project))
    if @role.save
      redirect_to action: :index
    else
      render :new
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: {role: @role} }
    end
  end

  def update
    if @role.update_attributes(role_params)
      redirect_to action: :index
    else
      render :show
    end
  end

  def destroy
    @role.soft_delete!
    redirect_to action: :index
  end

  private

  def find_role
    @role = Kubernetes::Role.not_deleted.find(params[:id])
  end

  def role_params
    params.require(:kubernetes_role).permit(:name, :config_file, :service_name, :resource_name, :autoscaled)
  end
end
