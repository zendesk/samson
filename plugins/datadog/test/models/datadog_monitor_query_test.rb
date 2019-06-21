# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DatadogMonitorQuery do
  let(:query) { DatadogMonitorQuery.new(query: '123', stage: stages(:test_staging)) }

  describe "validations" do
    def assert_request(to_return: {body: '{"name":"foo"}'}, &block)
      super(
        :get,
        "https://api.datadoghq.com/api/v1/monitor/123?api_key=dapikey&application_key=dappkey",
        to_return: to_return,
        &block
      )
    end

    it "is valid" do
      assert_request do
        assert_valid query
      end
    end

    it "is invalid with bad id" do
      query.query = "hey"
      refute_valid query
    end

    it "is invalid with bad monitor" do
      assert_request to_return: {status: 404} do
        refute_valid query
      end
    end

    it "does not make q request when query did not change" do
      assert_request do
        query.save!
        assert_valid query
      end
    end
  end

  describe "#monitors" do
    it "returns ids as monitors" do
      query.monitors.map(&:id).must_equal [123]
    end
  end
end
