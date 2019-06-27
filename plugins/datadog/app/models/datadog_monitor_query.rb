# frozen_string_literal: true
require 'datadog_monitor' # prevent random load errors in dev server

class DatadogMonitorQuery < ActiveRecord::Base
  # add new handling code to datadog_monitor.rb when adding
  MATCH_SOURCES = {
    "Group Permalink" => "deploy_group.permalink",
    "Group Env Value" => "deploy_group.env_value",
    "Environment Permalink" => "environment.permalink",
    "Cluster Permalink" => "kubernetes_cluster.permalink"
  }.freeze

  # add new handling code to samson_plugin.rb when adding
  FAILURE_BEHAVIORS = {
    "Redeploy previous" => "redeploy_previous",
    "Fail deploy" => "fail_deploy"
  }.freeze

  belongs_to :stage, inverse_of: :datadog_monitor_queries
  validates :query, format: /\A\d+\z|\A[a-z:,\d_-]+\z/
  validates :match_source, inclusion: MATCH_SOURCES.values, allow_blank: true
  validates :failure_behavior, inclusion: FAILURE_BEHAVIORS.values, allow_blank: true
  validate :validate_query_works, if: :query_changed?
  validate :validate_source_and_target

  def monitors
    @monitors ||= begin
      if single_monitor?
        [DatadogMonitor.new(query)]
      else
        DatadogMonitor.list(query)
      end.each do |m|
        # TODO: pass the whole query object
        m.match_target = match_target
        m.match_source = match_source
        m.failure_behavior = failure_behavior
      end
    end
  end

  def url
    if single_monitor?
      DatadogMonitor.new(query).url
    else
      q = URI.encode query.tr(",", " ") # rubocop:disable Lint/UriEscapeUnescape .to_query/CGI.escape do not work here
      "#{DatadogMonitor::BASE_URL}/monitors/manage?q=#{q}"
    end
  end

  private

  def validate_source_and_target
    errors.add :match_source, "cannot be set when target is not set." if match_source? ^ match_target?
  end

  def single_monitor?
    query.match? /\A\d+\z/
  end

  def validate_query_works
    return if errors[:query].any? # do not add to the pile
    return if monitors.any? && monitors.all? { |m| m.state([]) } # tag search failed or id search returned a bad monitor
    errors.add :query, "#{query} did not find monitors"
  end
end
