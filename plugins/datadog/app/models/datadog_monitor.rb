# frozen_string_literal: true
require 'faraday'

class DatadogMonitor
  API_KEY = ENV["DATADOG_API_KEY"]
  APP_KEY = ENV["DATADOG_APPLICATION_KEY"]
  SUBDOMAIN = ENV["DATADOG_SUBDOMAIN"] || "app"

  attr_reader :id

  def initialize(id)
    @id = Integer(id)
  end

  def state
    response[:overall_state]
  end

  def name
    response[:name] || 'api error'
  end

  def url
    "https://#{SUBDOMAIN}.datadoghq.com/monitors/#{id}"
  end

  private

  def response
    @response ||=
      begin
        url = "https://api.datadoghq.com/api/v1/monitor/#{@id}?api_key=#{API_KEY}&application_key=#{APP_KEY}"
        body = Faraday.new(request: {open_timeout: 2, timeout: 4}).get(url).body
        JSON.parse(body, symbolize_names: true)
      rescue StandardError => e
        Rails.logger.error("Datadog error #{e}")
        {}
      end
  end
end
