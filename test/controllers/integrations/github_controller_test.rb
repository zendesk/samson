require_relative '../../test_helper'

describe Integrations::GithubController do
  extend IntegrationsControllerTestHelper

  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }

  let(:payload) do
    {
      ref: 'refs/heads/dev',
      after: commit
    }.with_indifferent_access
  end

  before do
    Deploy.delete_all

    Integrations::GithubController.github_hook_secret = 'test'

    project.webhooks.create!(stage: stages(:test_staging), branch: "dev", source: 'github')
  end

  it 'does not deploy if signature is invalid' do
    request.headers['X-Github-Event'] = 'push'
    request.headers['X-Hub-Signature'] = "nope"

    post :create, payload.merge(token: project.token)

    project.deploys.must_equal []
    response.status.must_equal 200
  end

  it 'does not deploy if event is invalid' do
    request.headers['X-Github-Event'] = 'event'

    hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), 'test', payload.to_param)
    request.headers['X-Hub-Signature'] = "sha1=#{hmac}"

    post :create, payload.merge(token: project.token)

    project.deploys.must_equal []
    response.status.must_equal 200
  end

  describe 'with a valid signature' do
    let(:user_name) { 'Github' }

    before do
      request.headers['X-Github-Event'] = 'push'

      hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), 'test', payload.to_param)
      request.headers['X-Hub-Signature'] = "sha1=#{hmac}"
    end

    test_regular_commit "Github", no_mapping: { ref: 'refs/heads/foobar' }, failed: false
  end
end
