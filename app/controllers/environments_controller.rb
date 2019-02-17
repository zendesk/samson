# frozen_string_literal: true
class EnvironmentsController < ResourceController
  before_action :authorize_resource!
  before_action :find_resource, only: [:show, :update, :destroy]

  def new
    @environment = Environment.new
    render 'show'
  end

  def create
    super(template: :show)
  end

  def update
    super(template: :show)
  end

  private

  def search_resources
    Environment.all
  end

  def allowed_includes
    [:deploy_groups]
  end

  def resource_params
    params.require(:environment).permit(:name, :permalink, :production)
  end

  def resource_path
    environments_path
  end

  def environment
    @environment ||= Environment.find_by_param!(params[:id])
  end
end
