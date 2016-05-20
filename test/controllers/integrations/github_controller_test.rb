require_relative '../../test_helper'

SingleCov.covered!

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
  end

  does_not_deploy 'when the event is invalid' do
    request.headers['X-Github-Event'] = 'event'
  end

  it 'does not deploy if signature is invalid' do
    request.headers['X-Github-Event'] = 'push'
    request.headers['X-Hub-Signature'] = "nope"

    post :create, payload.merge(token: project.token)

    project.deploys.must_equal []
    response.status.must_equal 200
  end

  describe 'with a code push event' do
    before do
      request.headers['X-Github-Event'] = 'code_push'
      project.webhooks.create!(stage: stages(:test_staging), branch: "dev", source: 'github')
    end

    let(:user_name) { 'Github' }

    test_regular_commit "Github", no_mapping: { ref: 'refs/heads/foobar' }, failed: false do
      request.headers['X-Github-Event'] = 'push'
      hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), 'test', payload.to_param)
      request.headers['X-Hub-Signature'] = "sha1=#{hmac}"
    end
  end

  describe 'with a pull request event' do
    before do
      request.headers['X-Github-Event'] = 'pull_request'
      project.webhooks.create!(stage: stages(:test_staging), branch: "dev", source: 'any_pull_request')
    end

    let(:user_name) { 'Github' }
    let(:payload) do
      {
        ref: 'refs/heads/dev',
        after: commit,
        number: '42',
        pull_request: {state: 'open', body: 'imafixwolves [samson]'}
      }.with_indifferent_access
    end
    let(:api_response) do
      stub(
        user: stub(login: 'foo'),
        merged_by: stub(login: 'bar'),
        body: '',
        head: stub(sha: commit, ref: 'refs/heads/dev')
      )
    end

    does_not_deploy 'with a non-open pull request state' do
      payload.deep_merge!(pull_request: {state: 'closed'})
    end

    does_not_deploy 'without "[samson]" in the body' do
      payload.deep_merge!(pull_request: {body: 'imafixwolves'})
    end
  end
end
