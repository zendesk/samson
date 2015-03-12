require_relative '../test_helper'

describe DatadogMonitor do
  def stub_datadog(state)
    stub_request(:get, monitor_url).
      to_return(status: 200, body: api_response.merge("overall_state" => state).to_json)
  end

  def stub_datadog_timeout
    stub_request(:get, monitor_url).to_timeout
  end

  let(:monitor) { DatadogMonitor.new(123) }
  let(:monitor_url) { "https://app.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey" }
  let(:api_response) { JSON.parse('{"name":"Monitor Slow foo","query":"max(last_30m):max:foo.metric.time.max{*} > 20000","overall_state":"Ok","type":"metric alert","message":"This is mostly informative... @foo@bar.com","org_id":1234,"id":123,"options":{"notify_no_data":false,"no_data_timeframe":60,"notify_audit":false,"silenced":{}}}') }

  describe "#status" do
    it "passes when it passes" do
      stub_datadog("OK")
      monitor.status.must_equal :pass
    end

    it "fails when it fails" do
      stub_datadog("Alert")
      monitor.status.must_equal :fail
    end

    it "errors when it times out" do
      stub_datadog_timeout
      silence_stderr { monitor.status.must_equal :error }
    end
  end

  describe "#name" do
    it "is there" do
      stub_datadog("OK")
      monitor.name.must_equal "Monitor Slow foo"
    end

    it "is error when request times out" do
      stub_datadog_timeout
      silence_stderr { monitor.name.must_equal "error" }
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
