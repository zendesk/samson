# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe WebhookRecorder do
  let(:request) do
    request = ActionController::TestRequest.new(
      {
        "FOO" => "bar",
        "rack.foo" => "bar",
        "RAW_POST_DATA" => +"BODY",
        "rack.input" => {"foo" => "bar"},
        "QUERY_STRING" => "action=good&password=secret",
        "action_dispatch.parameter_filter" => Rails.application.config.filter_parameters
      }, {}, {}
    )
    request.stubs(:params).returns("action" => "create") # making sure nobody calls this (includes controller action)
    request
  end
  let(:response) { ActionDispatch::TestResponse.new }
  let(:project) { projects(:test) }

  describe ".record" do
    it "does not record internal rails/rack headers" do
      WebhookRecorder.record(project, request: request, log: "", response: response)
      WebhookRecorder.read(project).fetch(:request_headers).must_equal(
        "FOO" => "bar"
      )
    end

    it "records status, body, log" do
      WebhookRecorder.record(project, request: request, log: "LOG", response: response)
      read = WebhookRecorder.read(project)
      read.fetch(:response_code).must_equal 200
      read.fetch(:log).must_equal "LOG"
      read.fetch(:request_params).must_equal("action" => "good", "password" => "[FILTERED]")
    end

    it "does not blow up when receiving utf8 as ascii-8-bit which is the default" do
      bad = (+"EVIL->😈<-EVIL").force_encoding(Encoding::BINARY)
      bad.bytesize.must_equal 16
      request.env["RAW_POST_DATA"] = bad
      WebhookRecorder.record(project, request: request, log: "LOG", response: response)
      read = WebhookRecorder.read(project)
      read.fetch(:request_params).must_equal("action" => "good", "password" => "[FILTERED]")
    end
  end

  describe ".read" do
    it "reads" do
      WebhookRecorder.record(project, request: request, log: "", response: response)
      WebhookRecorder.read(project).class.must_equal ActiveSupport::HashWithIndifferentAccess
    end

    it "reads missing as nil" do
      WebhookRecorder.read(project).must_be_nil
    end
  end
end
