class NewRelicController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do
    head :not_found
  end

  before_filter do
    head(:not_found) unless NewRelicApi.api_key.present?
  end

  def show
    values = stage.new_relic_applications.map(&:name).inject({}) do |map, app_name|
      app = NewRelic.applications[app_name]
      map[app_name] = { id: app.id }

      if initial?
        map[app_name].merge!(
          historic_response_time: app.historic_response_time.map(&:last),
          historic_throughput: app.historic_throughput.map(&:last)
        )
      else
        map[app_name].merge!(response_time: app.response_time, throughput: app.throughput)
      end

      map
    end

    retval = { applications: values, count: values.size }

    if initial?
      retval.merge!(historic_times: historic_times)
    else
      retval.merge!(time: Time.now.utc.to_i)
    end

    render json: retval
  end

  private

  def historic_times
    time = Time.now.utc.to_i

    (0..30).inject([]) do |ary, i|
      ary.unshift(time - 60 * i)
    end
  end

  def initial?
    @initial ||= params[:initial] == 'true'
  end

  def stage
    @stage ||= project.stages.find(params[:id])
  end

  def project
    @project ||= Project.find(params[:project_id])
  end
end
