# frozen_string_literal: true
require 'faraday'

class DatadogMonitor
  API_KEY = ENV["DATADOG_API_KEY"]
  APP_KEY = ENV["DATADOG_APPLICATION_KEY"]
  SUBDOMAIN = ENV["DATADOG_SUBDOMAIN"] || "app"

  attr_reader :id

  class << self
    # returns raw data
    def get(id)
      request("/api/v1/monitor/#{id}", fallback: {})
    end

    # returns pre-filled [DatadogMonitor]
    def list(params)
      data = request("/api/v1/monitor", params: params, fallback: [{id: 0}])
      data.map { |d| new(d[:id], d) }
    end

    private

    def request(path, params: {}, fallback:)
      query = params.merge(api_key: API_KEY, application_key: APP_KEY).to_query
      url = "https://api.datadoghq.com#{path}?#{query}"
      response = Faraday.new(request: {open_timeout: 2, timeout: 4}).get(url)
      raise "Bad response #{response.status}" unless response.success?
      JSON.parse(response.body, symbolize_names: true)
    rescue StandardError => e
      Rails.logger.error("Datadog error #{e}")
      fallback
    end
  end

  def initialize(id, response = nil)
    @id = Integer(id)
    @response = response
  end

  def state
    response[:overall_state]
  end

  def name
    response[:name] || 'api error'
  end

  def url
    "https://#{SUBDOMAIN}.datadoghq.com/monitors/#{@id}"
  end

  private

  def response
    @response ||= self.class.get(@id)
  end
end
