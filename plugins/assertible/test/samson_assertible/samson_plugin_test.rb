# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonAssertible::Notification do
  describe '.deliver' do
    subject { SamsonAssertible::Notification.deliver(deploy) }

    let(:url_helpers) { Rails.application.routes.url_helpers }
    let(:deploy) { deploys(:succeeded_test) }

    before do
      deploy.stage.update_column(:notify_assertible, true)
    end

    with_env(ASSERTIBLE_SERVICE_KEY: 'test_token')
    with_env(ASSERTIBLE_DEPLOY_TOKEN: 'test_deploy')

    it "sends a notification" do
      assert_request(
        :post, "https://assertible.com/deployments",
        with: {
          body: {
            'service' => 'test_token',
            'environmentName' => deploy.stage.name,
            'version' => 'v1',
            url: url_helpers.project_deploy_url(
              id: deploy.id,
              project_id: deploy.project.id
            )
          }.to_json,
          basic_auth: ['test_deploy', '']
        }
      ) { subject }
    end

    context 'When no service key' do
      with_env(ASSERTIBLE_SERVICE_KEY: nil)

      it 'Does not send notification' do
        Faraday.expects(:post).never
        subject
      end
    end

    context 'When no deploy token' do
      with_env(ASSERTIBLE_DEPLOY_TOKEN: nil)

      it 'Does not send notification' do
        Faraday.expects(:post).never
        subject
      end
    end

    context 'When deploy fails' do
      let(:deploy) { deploys(:failed_staging_test) }

      it 'Does not send notification' do
        Faraday.expects(:post).never
        subject
      end
    end

    context 'When notifications are not enabled' do
      before do
        deploy.stage.update_column(:notify_assertible, false)
      end

      it 'Does not send notification' do
        Faraday.expects(:post).never
        subject
      end
    end
  end
end

describe :after_deploy do
  subject { Samson::Hooks.fire :after_deploy, deploy, users(:admin) }

  let(:deploy) { deploys(:succeeded_test) }

  it 'Triggers delivery' do
    SamsonAssertible::Notification.expects(:deliver).once
    subject
  end
end
