require_relative '../../test_helper'

describe Integrations::BuildkiteController do
  extend IntegrationsControllerTestHelper

  let(:commit) { 'dc395381e650f3bac18457909880829fc20e34ba' }
  let(:commit_message) { 'test' }
  let(:project) { projects(:test) }
  let(:payload) do
    {
      'build' => {
        'id'=>'e711180f-b318-4559-be4e-de119d2ac5eb',
        'url'=> 'https://api.buildkite.com/v1/organizations/my-org/projects/test/builds/9',
        'number'=>9,
        'state'=>'passed',
        'message'=>commit_message,
        'commit'=>commit,
        'branch'=>'master',
        'created_at'=>'2015-03-30 03:46:11 UTC',
        'scheduled_at'=>'2015-03-30 03:46:11 UTC',
        'started_at'=>'2015-03-30 03:46:15 UTC',
        'finished_at'=>'2015-03-30 03:46:22 UTC'
      },
      'project'=> {
        'id'=>'1db912ed-ca71-4d16-9c16-e453b88432cc',
        'url'=>'https://api.buildkite.com/v1/organizations/my-org/projects/test',
        'name'=>'We Build',
        'repository'=>'git@github.com:my-org/test.git'
      },
      'sender'=> {
        'id'=>'4fb41f57-c1d7-41b0-91e3-941edf19ac16', 'name'=>'Dude Rock'
      }
    }.with_indifferent_access
  end

  before { Deploy.delete_all }

  context 'when buildkite passes a build event' do
    test_regular_commit 'Buildkite', failed: { build: { state: 'failed' }}, no_mapping: { build: { branch: 'non-existent-branch' } } do
      project.webhooks.create!(stage: stages(:test_staging), branch: 'master', source: 'buildkite')
    end

    context 'when the commit message contains the skip message' do
      let(:commit_message) { 'I like to [deploy skip]' }

      it 'does not trigger a deploy' do
        project.webhooks.create!(stage: stages(:test_staging), branch: 'master', source: 'buildkite')
        post :create, payload.merge(token: project.token)

        project.deploys.must_equal []
      end
    end
  end

  context 'when buildkite does not pass a build event' do
    it 'does not create a deploy' do
      post :create, payload.merge(token: project.token)

      project.deploys.must_equal []
      response.status.must_equal 200
    end
  end
end
