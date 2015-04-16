class NewRelicController < ApplicationController
  before_action :ensure_new_reclic_api_key
  authorize_resource

  def show
    applications = stage.new_relic_applications.map(&:name)
    render json: NewRelic.metrics(applications, initial?)
  end

  private

  def initial?
    params[:initial] == 'true'
  end

  def stage
    Stage.where(project_id: Project.find_by_param!(params[:project_id])).find(params[:id])
  end

  def ensure_new_reclic_api_key
    return if NewRelicApi.api_key.present?
    head text: "NewReclic api key is not configured", status: :precondition_failed
  end
end
