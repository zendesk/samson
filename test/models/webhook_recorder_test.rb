# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe WebhookRecorder do
  let(:request) do
    ActionController::TestRequest.new({
      "FOO" => "bar",
      "rack.foo" => "bar",
      "RAW_POST_DATA" => "BODY".dup
    }, {})
  end
  let(:response) { ActionDispatch::TestResponse.new }
  let(:project) { projects(:test) }

  describe ".record" do
    it "does not record internal rails/rack headers" do
      WebhookRecorder.record(project, request: request, log: "", response: response)
      WebhookRecorder.read(project).fetch(:request).must_equal(
        "FOO" => "bar",
        "RAW_POST_DATA" => "BODY"
      )
    end

    it "records status, body, log" do
      WebhookRecorder.record(project, request: request, log: "LOG", response: response)
      read = WebhookRecorder.read(project)
      read.fetch(:status_code).must_equal 200
      read.fetch(:body).must_equal ""
      read.fetch(:log).must_equal "LOG"
      read.fetch(:request_body).must_equal "BODY"
    end
  end

  describe ".read" do
    it "reads" do
      WebhookRecorder.record(project, request: request, log: "", response: response)
      WebhookRecorder.read(project).class.must_equal ActiveSupport::HashWithIndifferentAccess
    end

    it "reads missing as nil" do
      WebhookRecorder.read(project).must_equal nil
    end
  end
end
