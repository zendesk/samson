# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { stages(:test_staging) }

  describe "assigning rollbar attributes" do
    it "assigns" do
      stage.attributes = {rollbar_webhooks_attributes: {0 => {webhook_url: 'xxxx'}}}
      stage.rollbar_webhooks.size.must_equal 1
    end

    it "does not assign without url" do
      stage.attributes = {rollbar_webhooks_attributes: {0 => {webhook_url: ''}}}
      stage.rollbar_webhooks.size.must_equal 0
    end
  end
end
