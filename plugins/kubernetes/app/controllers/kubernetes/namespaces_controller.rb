# frozen_string_literal: true
class Kubernetes::NamespacesController < ResourceController
  before_action :authorize_admin!, except: [:show, :index]
  before_action :set_resource, only: [:show, :update, :destroy, :new, :create]

  private

  def resource_params
    permitted = [:comment, {project_ids: []}]
    permitted << :name if ["new", "create"].include?(action_name)
    super.permit(*permitted)
  end
end
