# frozen_string_literal: true
require 'faraday'

class DatadogMonitor
  API_KEY = ENV["DATADOG_API_KEY"]
  APP_KEY = ENV["DATADOG_APPLICATION_KEY"]
  SUBDOMAIN = ENV["DATADOG_SUBDOMAIN"] || "app"
  BASE_URL = ENV["DATADOG_URL"] || "https://#{SUBDOMAIN}.datadoghq.com"
  GROUP_STATES = 'alert,warn'

  attr_reader :id
  attr_accessor :query

  class << self
    # returns raw data
    def get(id)
      request("/api/v1/monitor/#{id}", params: {group_states: GROUP_STATES}, fallback: {})
    end

    # returns pre-filled [DatadogMonitor]
    def list(tag_query)
      ignored, queried = tag_query.split(",").partition { |t| t.match?(/^-\d+$/) }
      data = request(
        "/api/v1/monitor",
        params: {monitor_tags: queried.join(","), group_states: GROUP_STATES}, fallback: [{id: 0}]
      )
      data.reject! { |d| ignored.include?("-#{d[:id]}") }
      data.map { |d| new(d[:id], d) }
    end

    private

    def request(path, fallback:, params: {})
      query = params.merge(api_key: API_KEY, application_key: APP_KEY).to_query
      url = "https://api.datadoghq.com#{path}?#{query}"
      response = Faraday.new(request: {open_timeout: 2, timeout: 4}).get(url)
      if response.success?
        JSON.parse(response.body, symbolize_names: true)
      elsif response.status == 404 # bad config, not our problem
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

  # @return [String,nil] "Alert", "Warn", "OK", "NoData"
  def state(deploy_groups)
    return unless response[:overall_state] # show fallback as warning

    if query.match_source?
      return "OK" unless groups = (response.dig(:state, :groups) || {}).presence
      deployed = deploy_groups.map { |dg| deploy_group_scope(dg) }
      groups.sort_by { |_, v| v[:status] }.each do |k, v|
        return v[:status] if (k.to_s.split(",") & deployed).any?
      end
      "OK"
    else
      response[:overall_state]
    end
  end

  def name
    response[:name] || 'api error'
  end

  def url(deploy_groups)
    base = "#{BASE_URL}/monitors/#{@id}"
    if deploy_groups.size == 1 && query.match_source?
      base += "?#{{q: deploy_group_scope(deploy_groups.first)}.to_query}"
    end
    base
  end

  def reload_from_api
    @response = nil
  end

  def response
    @response ||= self.class.get(@id)
  end

  private

  def deploy_group_scope(dg)
    "#{query.match_target}:#{match_value(dg)}"
  end

  def match_value(deploy_group)
    case query.match_source
    when "deploy_group.permalink" then deploy_group.permalink
    when "deploy_group.env_value" then deploy_group.env_value
    when "environment.permalink" then deploy_group.environment.permalink
    when "kubernetes_cluster.permalink"
      deploy_group.kubernetes_cluster ? deploy_group.kubernetes_cluster.name.tr(" ", "").downcase : "none"
    else raise ArgumentError, "Unsupported match_source #{query.match_source}"
    end
  end
end
