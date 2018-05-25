# frozen_string_literal: true
class EnvironmentVariablesController < ApplicationController
  before_action :authorize_admin!, except: [:index]

  def index
    scope = EnvironmentVariable
    search = params[:search] || {}
    scope = scope.where(name: search[:name]) if search[:name].present?
    scope = scope.where(value: search[:value]) if search[:value].present?
    @pagy, @environment_variables = pagy(scope, page: params[:page], items: 30)
  end

  def destroy
    EnvironmentVariable.find(params.require(:id)).destroy!
    head :ok
  end
end
