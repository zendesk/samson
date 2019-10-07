# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Deploy do
  let(:deploy) { Deploy.new }

  it "can assign datadog_monitors_for_rollback" do
    deploy.datadog_monitors_for_validation = 1
    deploy.datadog_monitors_for_validation.must_equal 1
  end
end
