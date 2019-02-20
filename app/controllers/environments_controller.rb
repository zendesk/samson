# frozen_string_literal: true
class EnvironmentsController < ResourceController
  before_action :authorize_resource!
  before_action :find_resource, only: [:show, :update, :destroy]

  def new
    super(template: :show)
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
    super.permit(:name, :permalink, :production)
  end
end
