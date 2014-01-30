require 'new_relic_api'

class NewRelicController < ApplicationController
  def show
    return head(:not_found) unless ENV['NEWRELIC_API_KEY']

    NewRelicApi.port    = 443
    NewRelicApi.api_key = ENV['NEWRELIC_API_KEY']

    apps = [
      'RS Production',
      'Pod2 Application Servers',
      'pod3 Application Servers'
    ]

    values = apps.inject({}) do |map, app_name|
      app = NewRelic.applications[app_name]
      map[app_name] = { id: app.id, response_time: app.response_time, throughput: app.throughput }
      map
    end

    render json: { time: Time.now.to_i, applications: values }
  end
end
