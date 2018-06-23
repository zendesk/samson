# frozen_string_literal: true
class EnvironmentVariablesController < ApplicationController
  before_action :authorize_admin!, except: [:index, :show, :update]
  before_action :environment_variable, only: [:show]

  def index
    scope = EnvironmentVariable
    search = params[:search] || {}
    scope = scope.where(name: search[:name]) if search[:name].present?
    scope = scope.where(value: search[:value]) if search[:value].present?
    @pagy, @environment_variables = pagy(scope, page: params[:page], items: 30)
  end

  def show
    render 'form'
  end

  def update
    environment_variable.attributes = attributes
    environment_variable.save!
    redirect_to action: :show
  end

  def destroy
    EnvironmentVariable.find(params.require(:id)).destroy!
    head :ok
  end

  def environment_variable
    @variable ||= EnvironmentVariable.find(params[:id])
  end

  def attributes
    params.require(:environment_variable).permit(
      :name,
      :description
    )
  end
end
