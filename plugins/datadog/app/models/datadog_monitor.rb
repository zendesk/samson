# frozen_string_literal: true
require 'faraday'

class DatadogMonitor
  API_KEY = ENV["DATADOG_API_KEY"]
  APP_KEY = ENV["DATADOG_APPLICATION_KEY"]
  SUBDOMAIN = ENV["DATADOG_SUBDOMAIN"] || "app"
  BASE_URL = ENV["DATADOG_URL"] || "https://#{SUBDOMAIN}.datadoghq.com"

  attr_reader :id
  attr_accessor :match_target, :match_source

  class << self
    # returns raw data
    def get(id)
      request("/api/v1/monitor/#{id}", params: {group_states: 'alert'}, fallback: {})
    end

    # returns pre-filled [DatadogMonitor]
    def list(tags)
      data = request("/api/v1/monitor", params: {monitor_tags: tags, group_states: 'alert'}, fallback: [{id: 0}])
      data.map { |d| new(d[:id], d) }
    end

    private

    def request(path, params: {}, fallback:)
      query = params.merge(api_key: API_KEY, application_key: APP_KEY).to_query
      url = "https://api.datadoghq.com#{path}?#{query}"
      response = Faraday.new(request: {open_timeout: 2, timeout: 4}).get(url)
      if response.success?
        JSON.parse(response.body, symbolize_names: true)
      elsif response.status == 404 # bad stage config, not our problem
        fallback
      else # datadog down, notify
        raise "Bad response #{response.status}"
      end
    rescue StandardError => e
      Samson::ErrorNotifier.notify(e)
      fallback
    end
  end

  def initialize(id, response = nil)
    @id = Integer(id)
    @response = response
  end

  # @return [String] nil, "Alert", "OK", "NoData"
  def state(deploy_groups)
    return unless response[:overall_state] # show fallback as warning

    if match_source.present?
      return "OK" unless alerting = alerting_tags.presence # be lazy
      deployed = deploy_groups.map { |dg| "#{match_target}:#{match_value(dg)}" }
      (deployed & alerting).any? ? "Alert" : "OK"
    else
      response[:overall_state]
    end
  end

  def name
    response[:name] || 'api error'
  end

  def url
    "#{BASE_URL}/monitors/#{@id}"
  end

  def reload
    @response = nil
  end

  private

  # alerting scopes, but ignore when it completely matches a silenced scope
  # @return [Array<String>]
  def alerting_tags
    alerting = tags_from_response(:state, :groups)
    silenced = tags_from_response(:options, :silenced)
    alerting.reject! { |scope| silenced.any? { |s| (s & scope) == s } }
    alerting.flatten(1)
  end

  # @return [Array<Array<String>>]
  def tags_from_response(*path)
    hash = response.dig(*path) || {}
    hash.keys.map { |k| k.to_s.split(",").sort }
  end

  def match_value(deploy_group)
    case match_source
    when "deploy_group.permalink" then deploy_group.permalink
    when "deploy_group.env_value" then deploy_group.env_value
    when "environment.permalink" then deploy_group.environment.permalink
    when "kubernetes_cluster.permalink"
      deploy_group.kubernetes_cluster ? deploy_group.kubernetes_cluster.name.tr(" ", "").downcase : "none"
    else raise ArgumentError, "Unsupported match_source #{match_source}"
    end
  end

  def response
    @response ||= self.class.get(@id)
  end
end
