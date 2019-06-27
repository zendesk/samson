# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DatadogMonitorQuery do
  let(:query) { DatadogMonitorQuery.new(query: '123', scope: stages(:test_staging)) }

  describe "validations" do
    def assert_id_request(to_return: {body: '{"overall_state":"OK"}'}, &block)
      assert_request(
        :get,
        "#{api_url}/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert",
        to_return: to_return,
        &block
      )
    end

    def assert_tag_request(response, &block)
      q = "foo:bar,bar:vaz"
      query.query = q
      url = "#{api_url}/monitor?api_key=dapikey&application_key=dappkey&group_states=alert&monitor_tags=#{q}"
      assert_request(:get, url, to_return: {body: response.to_json}, &block)
    end

    let(:api_url) { "https://api.datadoghq.com/api/v1" }

    it "is valid" do
      assert_id_request do
        assert_valid query
      end
    end

    it "is invalid with bad monitor id" do
      assert_id_request to_return: {status: 404} do
        refute_valid query
      end
    end

    it "is invalid with bad monitor tag" do
      assert_id_request to_return: {status: 404} do
        refute_valid query
      end
    end

    it "is invalid with bad monitor tags" do
      query.query = "team/foo"
      refute_valid query
    end

    it "is valid with good monitor multi-tags" do
      assert_tag_request([{id: 123, overall_state: "OK"}]) do
        assert_valid query
      end
    end

    it "is invalid with bad monitor multi-tags" do
      assert_tag_request([]) do
        refute_valid query
      end
    end

    it "is valid with good monitor multi-tags" do
      query.query = "team:foo,team:bar"
    end

    it "does not make q request when query did not change" do
      assert_id_request do
        query.save!
        assert_valid query
      end
    end

    it "does not allow source without target" do
      assert_id_request do
        query.match_target = "foo"
        refute_valid query
      end
    end

    describe "#validate_duration_used_with_failure" do
      it "does not allow setting duration without failure" do
        assert_id_request do
          query.check_duration = 60
          refute_valid query
        end
      end

      it "allows duration with failure" do
        assert_id_request do
          query.check_duration = 60
          query.failure_behavior = "fail_deploy"
          assert_valid query
        end
      end
    end
  end

  describe "#monitors" do
    it "returns ids as monitors" do
      query.monitors.map(&:id).must_equal [123]
    end

    it "caches monitors so we can preload them in parallel" do
      query.monitors.object_id.must_equal query.monitors.object_id
    end
  end

  describe "#url" do
    it "builds for monitors" do
      query.url.must_equal "https://app.datadoghq.com/monitors/123"
    end

    it "builds for simple tags" do
      query.query = "foo"
      query.url.must_equal "https://app.datadoghq.com/monitors/manage?q=foo"
    end

    it "does not use + when searching for multiple tags because datadog UI does not support it" do
      query.query = "foo,bar"
      query.url.must_equal "https://app.datadoghq.com/monitors/manage?q=foo%20bar"
    end
  end
end
