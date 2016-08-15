# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Integrations::BuildkiteController do
  extend IntegrationsControllerTestHelper

  let(:commit) { 'dc395381e650f3bac18457909880829fc20e34ba' }
  let(:commit_message) { 'test' }
  let(:project) { projects(:test) }
  let(:payload) do
    {
      'build' => {
        'id' => 'e711180f-b318-4559-be4e-de119d2ac5eb',
        'url' => 'https://api.buildkite.com/v1/organizations/my-org/projects/test/builds/9',
        'number' => 9,
        'state' => 'passed',
        'message' => commit_message,
        'commit' => commit,
        'branch' => 'master',
        'created_at' => '2015-03-30 03:46:11 UTC',
        'scheduled_at' => '2015-03-30 03:46:11 UTC',
        'started_at' => '2015-03-30 03:46:15 UTC',
        'finished_at' => '2015-03-30 03:46:22 UTC'
      },
      'project' => {
        'id' => '1db912ed-ca71-4d16-9c16-e453b88432cc',
        'url' => 'https://api.buildkite.com/v1/organizations/my-org/projects/test',
        'name' => 'We Build',
        'repository' => 'git@github.com:my-org/test.git'
      },
      'sender' => {
        'id' => '4fb41f57-c1d7-41b0-91e3-941edf19ac16', 'name' => 'Dude Rock'
      }
    }.with_indifferent_access
  end

  before do
    Deploy.delete_all
    project.webhooks.create!(stage: stages(:test_staging), branch: 'master', source: 'buildkite')
  end

  context 'when buildkite passes a build event' do
    options = {failed: { build: { state: 'failed' }}, no_mapping: { build: { branch: 'non-existent-branch' } }}
    test_regular_commit 'Buildkite', options
    it_ignores_skipped_commits
  end

  context 'when buildkite does not pass a build event' do
    it 'does not create a deploy' do
      payload.delete(:build)
      post :create, payload.merge(token: project.token)

      project.deploys.must_equal []
      response.status.must_equal 200
    end
  end

  context 'when the buildkite_release_params hook gets trigger' do
    let(:buildkite_build_number) { lambda { |_, _| [[:number, 9]] } }
    before do
      project.releases.destroy_all
      project.builds.destroy_all
      Integrations::BuildkiteController.any_instance.stubs(:project).returns(project)
      project.stubs(:create_releases_for_branch?).returns(true)
      Build.any_instance.stubs(:validate_git_reference).returns(true)
      stub_request(:post, "https://api.github.com/repos/bar/foo/releases").
        to_return(status: 200, body: "", headers: {})
    end

    it 'creates the release with the buildkite build number' do
      Samson::Hooks.with_callback(:buildkite_release_params, buildkite_build_number) do |_|
        post :create, payload.merge(token: project.token), test_route: true

        project.releases.size.must_equal 1
        project.releases.first.number.must_equal 9
      end
    end
  end
end
