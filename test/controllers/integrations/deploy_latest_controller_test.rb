require_relative '../../test_helper'

describe Integrations::DeployLatestController do
  let(:project)        { projects(:test) }
  let(:stage)          { project.stages.detect { |stage| stage.permalink == 'staging' } }
  let(:latest_release) { project.releases.last }

  before do
    Deploy.delete_all

    Rails.application.config.samson.webhook_secret = 'correct'
  end

  context 'when the correct webhook secret is provided' do
    before { request.headers['X-Webhook-Secret'] = 'correct' }

    context 'when the latest release is not yet deployed' do
      it 'returns a 200 response and deploys the latest release' do
        post :create, token: project.token, stage: 'staging'

        project.deploys.size.must_equal 1
        response.status.must_equal 200
      end
    end

    context 'when the latest release is already deployed' do
      let(:deploy) { stage.create_deploy(user: User.first, reference: latest_release.version) }
      before { deploy.job.success! }

      it 'returns a 422 response and does not create a new deploy' do
        post :create, token: project.token, stage: 'staging'

        project.deploys.must_equal [deploy]
        response.status.must_equal 422
      end
    end

    context 'when the stage is currently deploying' do
      let(:deploy) { stage.create_deploy(user: User.first, reference: latest_release.version) }
      before { puts deploy.job.run! }

      it 'returns a 422 response and does not create a deploy' do
        post :create, token: project.token, stage: 'staging'

        project.deploys.must_equal [deploy]
        response.status.must_equal 422
      end
    end
  end

  context 'when the webhook secret is incorrect' do
    before { request.headers['X-Webhook-Secret'] = 'incorrect' }

    it 'returns an anauthenticated error with incorrect webhook secret and does not create a deploy' do
      post :create, token: project.token, stage: 'staging'

      project.deploys.must_equal []
      response.status.must_equal 401
    end
  end
end
