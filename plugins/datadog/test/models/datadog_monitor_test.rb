# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DatadogMonitor do
  def assert_datadog(state:, status: 200, &block)
    assert_request(
      :get, monitor_url,
      to_return: {body: api_response.merge("overall_state" => state).to_json, status: status},
      &block
    )
  end

  def assert_datadog_timeout(&block)
    assert_request(:get, monitor_url, to_timeout: [], &block)
  end

  let(:monitor) { DatadogMonitor.new(123) }
  let(:monitor_url) { "https://api.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey" }
  let(:api_response) { JSON.parse('{"name":"Monitor Slow foo","query":"max(last_30m):max:foo.metric.time.max{*} > 20000","overall_state":"Ok","type":"metric alert","message":"This is mostly informative... @foo@bar.com","org_id":1234,"id":123,"options":{"notify_no_data":false,"no_data_timeframe":60,"notify_audit":false,"silenced":{}}}') } # rubocop:disable Metrics/LineLength

  describe "#state" do
    it "returns state" do
      assert_datadog(state: "OK") do
        monitor.state.must_equal "OK"
      end
    end
  end

  describe "#name" do
    it "is there" do
      assert_datadog(state: "OK") do
        monitor.name.must_equal "Monitor Slow foo"
      end
    end

    it "is error when request times out" do
      assert_datadog_timeout do
        silence_stderr { monitor.name.must_equal "api error" }
      end
    end

    it "is error when request fails" do
      assert_datadog(state: "OK", status: 404) do
        silence_stderr { monitor.name.must_equal "api error" }
      end
    end
  end

  describe "#url" do
    it "builds a url" do
      monitor.url.must_equal "https://app.datadoghq.com/monitors/123"
    end
  end

  describe "caching" do
    it "caches the api response" do
      assert_datadog(state: "OK") do
        monitor.name
        monitor.state
      end
    end
  end
end
