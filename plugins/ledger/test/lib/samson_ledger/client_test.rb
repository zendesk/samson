# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe SamsonLedger::Client do
  with_env(LEDGER_BASE_URL: 'https://foo.bar', LEDGER_TOKEN: "sometoken")

  describe ".post_deployment" do
    let(:deploy) { Deploy.first }
    let(:results) { [] }
    let(:response) { {status: 200} }
    let(:sawyer_agent) { Sawyer::Agent.new('') }
    let(:comparison) { Sawyer::Resource.new(sawyer_agent, commits: [commit]) }
    let(:commit) { Sawyer::Resource.new(sawyer_agent, commit: commit_message) }
    let(:commit_message) { Sawyer::Resource.new(sawyer_agent, message: 'Merge pull request #42') }
    let(:pull_request) do
      Sawyer::Resource.new(
        sawyer_agent,
        users:  [github_user],
        number: 42,
        url:    'http://some-github-url',
        title:  'some pr title'
      )
    end
    let(:github_user) { nil }

    before do
      Project.any_instance.stubs(:github?).returns(true)
      stub_github_api("repos/bar/foo/compare/abcabcaaabcabcaaabcabcaaabcabcaaabcabca1...staging", "x" => "y")
      GITHUB.stubs(:compare).with("bar/foo", "abcabcaaabcabcaaabcabcaaabcabcaaabcabca1", "staging").returns(comparison)
      Changeset::PullRequest.stubs(:find).with("bar/foo", 42).returns(pull_request)
      GITHUB.stubs(:pull_requests).with("bar/foo", head: "bar:staging").returns([])

      request_lambda = ->(request) do
        results << JSON.parse(request.body)['events'].first
        request
      end
      @event_sent = stub_request(:post, "https://foo.bar/api/v1/events").with(&request_lambda).to_return(response)
    end

    it "posts an event with a valid client" do
      SamsonLedger::Client.post_deployment(deploy)
      assert_requested(@event_sent)
    end

    it "does not stop all deploys when ledger does not reply" do
      sent = stub_request(:post, "https://foo.bar/api/v1/events").to_timeout
      Samson::ErrorNotifier.expects(:notify)
      SamsonLedger::Client.post_deployment(deploy)
      assert_requested(sent)
    end

    it "does not post an event without token" do
      ENV.delete 'LEDGER_TOKEN'
      SamsonLedger::Client.post_deployment(deploy)
      assert_not_requested(@event_sent)
    end

    it "does not post an event without url" do
      ENV.delete 'LEDGER_BASE_URL'
      SamsonLedger::Client.post_deployment(deploy)
      assert_not_requested(@event_sent)
    end

    it "does not post an event when no_code_deployed" do
      deploy.stage.update!(no_code_deployed: true)
      SamsonLedger::Client.post_deployment(deploy)
      assert_not_requested(@event_sent)
    end

    describe "started_at" do
      it "posts the updated_at of the deploy as started_at in iso8601" do
        SamsonLedger::Client.post_deployment(deploy)

        results.first['started_at'].must_equal(deploy.updated_at.iso8601)
      end
    end

    describe "pods" do
      it "posts an array of pod ids" do
        SamsonLedger::Client.post_deployment(deploy)

        results.first['pods'].must_equal([100])
      end

      describe "when the env_value of a deploy group is not a pod" do
        before do
          prod_env = environments(:production)

          deploy.stage.deploy_groups << DeployGroup.create!(name: "foo", environment: prod_env)
          deploy.stage.deploy_groups << DeployGroup.create!(name: "staging666", environment: prod_env)
          deploy.stage.deploy_groups << DeployGroup.create!(name: "master777", environment: prod_env)
        end

        it "ignores the env_value that is not a pod" do
          SamsonLedger::Client.post_deployment(deploy)

          results.first['pods'].must_equal([100, 666, 777])
        end
      end
    end

    describe "pull_requests" do
      let(:github_user) do
        Sawyer::Resource.new(
          sawyer_agent,
          url: 'http://some-github-user-url',
          avatar_url: 'http://some-github-user-avatar-url'
        )
      end

      it "constructs an unordered list of pull requests" do
        SamsonLedger::Client.post_deployment(deploy)

        results.first['pull_requests'].must_include(github_user.avatar_url)
        results.first['pull_requests'].must_include(github_user.url)
        results.first['pull_requests'].must_include("##{pull_request.number}")
        results.first['pull_requests'].must_include(pull_request.url)
        results.first['pull_requests'].must_include(pull_request.title)
      end

      it "does not include pull requests when none were found" do
        Changeset::PullRequest.stubs(:find).returns(nil)
        SamsonLedger::Client.post_deployment(deploy)
        results.first['pull_requests'].must_be_nil
      end
    end

    describe "when response status code is not 200" do
      let(:response) { {status: 401} }

      it "rejects our token" do
        results = SamsonLedger::Client.post_deployment(deploy)
        results.status.to_i.must_equal(401)
      end
    end
  end
end
