# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DatadogMonitor do
  def assert_datadog(state:, status: 200, times: 1, &block)
    assert_request(
      :get, monitor_url,
      to_return: {body: api_response.merge("overall_state" => state).to_json, status: status},
      times: times,
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

  describe "#alert?" do
    it "is alert when alerting" do
      assert_datadog(state: "Alert") do
        monitor.alert?.must_equal true
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
      Samson::ErrorNotifier.expects(:notify)
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

    it "expires the cache when reloaded" do
      assert_datadog(state: "OK", times: 2) do
        monitor.name
        monitor.reload
        monitor.name
      end
    end
  end

  describe ".list" do
    let(:url) { "https://api.datadoghq.com/api/v1/monitor?api_key=dapikey&application_key=dappkey" }

    it "finds multiple" do
      assert_request(:get, url, to_return: {body: [{id: 1, name: "foo"}].to_json}) do
        DatadogMonitor.list({}).map(&:name).must_equal ["foo"]
      end
    end

    it "adds params" do
      assert_request(:get, url + "&foo=bar", to_return: {body: [{id: 1, name: "foo"}].to_json}) do
        DatadogMonitor.list(foo: "bar")
      end
    end

    it "shows api error in the UI when it times out" do
      Samson::ErrorNotifier.expects(:notify)
      assert_request(:get, url, to_timeout: []) do
        DatadogMonitor.list({}).map(&:name).must_equal ["api error"]
      end
    end

    it "shows api error in the UI when it fails" do
      Samson::ErrorNotifier.expects(:notify)
      assert_request(:get, url, to_return: {status: 500}) do
        DatadogMonitor.list({}).map(&:name).must_equal ["api error"]
      end
    end
  end
end
