# frozen_string_literal: true
class NewRelicController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!
  before_action :ensure_new_reclic_api_key

  def show
    applications = stage.new_relic_applications.map(&:name)
    render json: SamsonNewRelic::Api.metrics(applications, initial: initial?)
  end

  private

  def initial?
    params[:initial] == 'true'
  end

  def stage
    Stage.where(project_id: @project).find_by_param!(params[:stage_id])
  end

  def ensure_new_reclic_api_key
    return if SamsonNewRelic.enabled?
    render plain: "NewReclic api key is not configured", status: :precondition_failed
  end
end
