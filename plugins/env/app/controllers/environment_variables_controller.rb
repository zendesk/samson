# frozen_string_literal: true
class EnvironmentVariablesController < ApplicationController
  before_action :authorize_admin!, except: [:index]

  def index
    scope = EnvironmentVariable.where(search_params)
    respond_to do |format|
      format.html do
        @pagy, @environment_variables = pagy(scope, page: params[:page], items: 30)
      end
      format.json do
        render_as_json :environment_variables, scope
      end
    end
  end

  def destroy
    EnvironmentVariable.find(params.require(:id)).destroy!
    head :ok
  end

  private

  def search_params
    permitted = params.fetch(:search, {}).permit(:id, :name, :value, :parent_id, :parent_type, :scope_id, :scope_type)
    permitted.select { |_, v| v.present? }
  end
end
