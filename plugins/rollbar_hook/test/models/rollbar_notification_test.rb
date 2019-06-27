# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe RollbarNotification do
  let(:endpoint) { 'https://rollbar.com' }
  def notification(token = 'token')
    RollbarNotification.new(
      webhook_url: endpoint,
      access_token: token,
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
          revision: 'v1',
          local_username: 'Samson'
        }
      )

      notification.deliver
      assert_requested request
    end

    it 'shows an error message' do
      stub_request(:post, endpoint).to_return(
        status: [500, "Internal Server Error"],
        body: 'oops..'
      )

      Rails.logger.expects(:info).with("Sending Rollbar notification...")
      Rails.logger.expects(:info).with("Failed to send Rollbar notification. HTTP 500: oops..")

      notification.deliver
    end
  end
end
