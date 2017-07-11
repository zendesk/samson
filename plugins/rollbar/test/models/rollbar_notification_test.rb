# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 2

describe RollbarNotification do
  let(:endpoint) { 'https://rollbar.com' }
  let(:notification) do
    RollbarNotification.new(
      webhook_url: endpoint,
      access_token: 'token',
      environment: 'test',
      revision: 'v1'
    )
  end

  describe '#deliver' do
    it 'notifies rollbar' do
      request = stub_request(:post, endpoint).with(
        body: {
          access_token: 'token',
          environment: 'test',
          revision: 'v1'
        }
      )

      notification.deliver
      assert_requested request
    end
  end
end
