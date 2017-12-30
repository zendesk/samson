# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DatadogMonitor do
  def assert_datadog(state, &block)
    assert_request(
      :get, monitor_url,
      to_return: {body: api_response.merge("overall_state" => state).to_json},
      &block
    )
  end

  def assert_datadog_timeout(&block)
    assert_request(:get, monitor_url, to_timeout: [], &block)
  end

  let(:monitor) { DatadogMonitor.new(123) }
  let(:monitor_url) { "https://app.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey" }
  let(:api_response) { JSON.parse('{"name":"Monitor Slow foo","query":"max(last_30m):max:foo.metric.time.max{*} > 20000","overall_state":"Ok","type":"metric alert","message":"This is mostly informative... @foo@bar.com","org_id":1234,"id":123,"options":{"notify_no_data":false,"no_data_timeframe":60,"notify_audit":false,"silenced":{}}}') } # rubocop:disable Metrics/LineLength

  describe "#status" do
    it "passes when it passes" do
      assert_datadog("OK") do
        monitor.status.must_equal :pass
      end
    end

    it "fails when it fails" do
      assert_datadog("Alert") do
        monitor.status.must_equal :fail
      end
    end

    it "errors when it times out" do
      assert_datadog_timeout do
        silence_stderr { monitor.status.must_equal :error }
      end
    end
  end

  describe "#name" do
    it "is there" do
      assert_datadog("OK") do
        monitor.name.must_equal "Monitor Slow foo"
      end
    end

    it "is error when request times out" do
      assert_datadog_timeout do
        silence_stderr { monitor.name.must_equal "error" }
      end
    end
  end

  describe "caching" do
    it "caches the api response" do
      Dogapi::Client.any_instance.expects(:get_monitor).returns([{}])
      monitor.name
      monitor.status
    end
  end
end
