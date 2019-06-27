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

    with_env(
      ASSERTIBLE_SERVICE_KEY: 'test_token',
      ASSERTIBLE_DEPLOY_TOKEN: 'test_deploy'
    )

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

    it "does not send notifications without service key" do
      with_env(ASSERTIBLE_SERVICE_KEY: nil) do
        assert_raises(KeyError) { subject }
      end
    end

    it "does not send notifications without service key" do
      with_env(ASSERTIBLE_DEPLOY_TOKEN: nil) do
        assert_raises(KeyError) { subject }
      end
    end

    context 'when deploy fails' do
      let(:deploy) { deploys(:failed_staging_test) }

      it 'does not send notification' do
        subject
      end
    end

    context 'when notifications are not enabled' do
      before do
        deploy.stage.update_column(:notify_assertible, false)
      end

      it 'does not send notification' do
        subject
      end
    end
  end
end

describe :after_deploy do
  subject { Samson::Hooks.fire :after_deploy, deploy, stub(output: nil) }

  let(:deploy) { deploys(:succeeded_test) }

  it 'triggers delivery' do
    SamsonAssertible::Notification.expects(:deliver).once
    subject
  end
end

describe :stage_permitted_params do
  it "adds notify_assertible" do
    Samson::Hooks.fire(:stage_permitted_params).must_include :notify_assertible
  end
end
