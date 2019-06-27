# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe AcceptsDatadogMonitorQueries do
  it "has datadog_monitor_queries" do
    Project.new.datadog_monitor_queries
  end
end
