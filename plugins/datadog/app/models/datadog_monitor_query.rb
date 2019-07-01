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

  belongs_to :scope, inverse_of: :datadog_monitor_queries, polymorphic: true
  validates :query, format: /\A\d+\z|\A[a-z:,\d_-]+\z/
  validates :match_source, inclusion: MATCH_SOURCES.values, allow_blank: true
  validates :failure_behavior, inclusion: FAILURE_BEHAVIORS.values, allow_blank: true
  validate :validate_query_works
  validate :validate_source_and_target
  validate :validate_duration_used_with_failure

  def monitors
    @monitors ||= begin
      if single_monitor?
        [DatadogMonitor.new(query)]
      else
        DatadogMonitor.list(query)
      end.each { |m| m.query = self }
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

  def validate_duration_used_with_failure
    errors.add :check_duration, "only set when also using 'On Alert'." if check_duration? && !failure_behavior?
  end

  def validate_source_and_target
    errors.add :match_source, "cannot be set when target is not set." if match_source? ^ match_target?
  end

  def single_monitor?
    query.match? /\A\d+\z/
  end

  def validate_query_works
    return if !query_changed? && !match_target_changed?
    return if errors[:query].any? # do not add to the pile

    # tag search failed or id search returned a bad monitor
    if monitors.none? || monitors.any? { |m| !m.state([]) }
      return errors.add :query, "did not find monitors"
    end

    # match_tag is not in monitors grouping so it will never alert
    if match_target?
      monitors.each do |m|
        groups = (m.response[:query][/\.by\(([^)]*)\)/, 1] || m.response[:query][/ by {([^}]*)}/, 1])
        next if groups.to_s.tr('"\'', '').split(",").include?(match_target)

        errors.add(
          :match_target, "#{match_target} must appear in #{m.url} grouping so it can trigger alerts for this tag"
        )
      end
    end
  end
end
