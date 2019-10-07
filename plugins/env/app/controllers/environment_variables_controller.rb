# frozen_string_literal: true
class EnvironmentVariablesController < ResourceController
  before_action :authorize_admin!, except: [:index]
  before_action :set_resource, only: [:destroy]

  # js does not want a redirect ... and .json with head response fails too, so we do it manually
  def destroy
    @environment_variable.destroy!
    head :ok
  end

  private

  def search_resources
    permitted = params.
      fetch(:search, {}).
      permit(:id, :name, :value, :parent_id, :parent_type, :scope_id, :scope_type).
      select { |_, v| v.present? }
    super.where(permitted)
  end
end
