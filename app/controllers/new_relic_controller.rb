class NewRelicController < ApplicationController
  before_filter :authorize_deployer!

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  before_filter :not_found, unless: -> { NewRelicApi.api_key.present? }

  def show
    applications = stage.new_relic_applications.map(&:name)
    render json: NewRelic.metrics(applications, initial?)
  end

  private

  def initial?
    params[:initial] == 'true'
  end

  def stage
    Stage.where(project_id: params[:project_id]).find(params[:id])
  end

  def not_found
    render json: {}, status: :not_found
  end
end
