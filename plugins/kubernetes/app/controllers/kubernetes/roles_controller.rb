# frozen_string_literal: true
class Kubernetes::RolesController < ResourceController
  include CurrentProject

  DEFAULT_BRANCH = 'master'

  PUBLIC = [:index, :show, :example].freeze
  before_action :authorize_project_deployer!, except: PUBLIC
  before_action :authorize_project_admin!, except: PUBLIC
  before_action :set_resource, only: [:show, :update, :destroy, :new, :create]

  def seed
    begin
      Kubernetes::Role.seed!(@project, params[:ref].presence || DEFAULT_BRANCH)
    rescue Samson::Hooks::UserError
      flash[:alert] = helpers.simple_format($!.message)
    end
    redirect_to action: :index
  end

  def example
  end

  private

  def search_resources
    resource_class.where(project: current_project).order(:name)
  end

  def resource_class
    super.not_deleted
  end

  def resource_path
    [@project, @resource]
  end

  def resources_path
    [@project, Kubernetes::Role]
  end

  def resource_params
    super.permit(
      :name, :config_file, :service_name, :resource_name, :autoscaled, :blue_green, :manual_deletion_acknowledged
    ).merge(project: @project)
  end
end
