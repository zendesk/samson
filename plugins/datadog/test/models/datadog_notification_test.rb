# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DatadogNotification do
  let(:deploy) { deploys(:succeeded_test) }
  let(:notification) { DatadogNotification.new(deploy) }

  describe '#initialize' do
    it 'initializes' do
      notification.instance_variable_get(:@deploy).must_equal deploy
      notification.instance_variable_get(:@stage).must_equal deploy.stage
    end
  end

  describe '#deliver' do
    def expected_body(overrides = {})
      {
        title: 'Super Admin deployed staging to Staging',
        text: 'super-admin@example.com deployed staging to Staging',
        alert_type: 'success',
        source_type_name: 'samson',
        date_happened: 1388607000,
        tags: ['deploy']
      }.merge(overrides).to_json
    end

    let(:url) { 'https://api.datadoghq.com/api/v1/events?api_key=dapikey' }

    it 'delivers correct notification with deploy updated_at' do
      assert_request(:post, url, with: {body: expected_body}) do
        notification.deliver
      end
    end

    it 'delivers correct notification with current time' do
      freeze_time
      assert_request(:post, url, with: {body: expected_body(date_happened: Time.now.to_i)}) do
        notification.deliver(now: true)
      end
    end

    it 'delivers correct notification with additional tags' do
      freeze_time
      assert_request(:post, url, with: {body: expected_body(tags: ['deploy', 'one', 'two'])}) do
        notification.deliver(additional_tags: ['one', 'two'])
      end
    end

    it 'delivers info notification if deploy is in progress' do
      deploy.job.update_column(:status, 'running')

      expected_values = {
        alert_type: 'info',
        title: 'Super Admin is deploying staging to Staging'
      }

      assert_request(:post, url, with: {body: expected_body(expected_values)}) do
        notification.deliver
      end
    end

    it 'delivers error notification if deploy did not succeed' do
      deploy.job.update_column(:status, 'failed')

      expected_values = {
        alert_type: 'error',
        title: 'Super Admin failed to deploy staging to Staging'
      }
      assert_request(:post, url, with: {body: expected_body(expected_values)}) do
        notification.deliver
      end
    end

    it 'logs success message if status is 202' do
      assert_request(:post, url, with: {body: expected_body}, to_return: {status: 202}) do
        notification.deliver
      end
    end

    it 'logs failure message if status is not 202' do
      Samson::ErrorNotifier.expects(:notify)
      assert_request(:post, url, with: {body: expected_body}, to_return: {status: 400}) do
        notification.deliver
      end
    end

    it "notifies of errors but does not block deploys when datadog is unreachable" do
      Samson::ErrorNotifier.expects(:notify)
      assert_request(:post, url, with: {body: expected_body}, to_timeout: []) do
        notification.deliver
      end
    end
  end
end
