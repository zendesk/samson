# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe 'SamsonLedger::Client' do
  include StructHelper

  let(:deploy) { Deploy.first }

  with_env(LEDGER_BASE_URL: 'https://foo.bar', LEDGER_TOKEN: "sometoken")

  describe ".plugin_enabled?" do
    it "is enabled" do
      assert SamsonLedger::Client.plugin_enabled?
    end

    it "is not enabled without token" do
      ENV.delete("LEDGER_TOKEN")
      refute SamsonLedger::Client.plugin_enabled?
    end

    it "is not enabled without base_url" do
      ENV.delete("LEDGER_BASE_URL")
      refute SamsonLedger::Client.plugin_enabled?
    end
  end

  describe ".post_deployment" do
    before do
      stub_github_api("repos/bar/foo/compare/abcabc1...staging", "x" => "y")
      GITHUB.stubs(:compare).with("bar/foo", "abcabc1", "staging").returns(comparison_struct.new([commit]))
      Changeset::PullRequest.stubs(:find).with("bar/foo", 42).returns(pull_request)

      request_lambda = -> (request) do
        results << JSON.parse(request.body)['events'].first
        request
      end
      @event_sent = stub_request(:post, "https://foo.bar/api/v1/events").with(&request_lambda).to_return(response)
    end

    let(:results) { [] }
    let(:response) { {status: 200} }

    let(:comparison_struct) { create_singleton_struct('ComparisonStruct', :commits) }
    let(:commit_struct) { create_singleton_struct('CommitStruct', :commit) }
    let(:message_struct) { create_singleton_struct('MessageStruct', :message) }
    let(:pull_request_struct) { create_singleton_struct('PullRequestStruct', :users, :number, :url, :title) }
    let(:github_user_struct) { create_singleton_struct('GithubUserStruct', :url, :avatar_url) }

    let(:commit) { commit_struct.new(message_struct.new("Merge pull request #42")) }
    let(:pull_request) { pull_request_struct.new([github_user], 42, 'http://some-github-url', 'some pr title') }
    let(:github_user) { nil }

    it "posts an event with a valid client" do
      SamsonLedger::Client.post_deployment(deploy)
      assert_requested(@event_sent)
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
      let(:github_user) { github_user_struct.new('http://some-github-user-url', 'http://some-github-user-avatar-url') }

      it "constructs an unordered list of pull requests" do
        SamsonLedger::Client.post_deployment(deploy)

        results.first['pull_requests'].must_include(github_user.avatar_url)
        results.first['pull_requests'].must_include(github_user.url)
        results.first['pull_requests'].must_include("##{pull_request.number}")
        results.first['pull_requests'].must_include(pull_request.url)
        results.first['pull_requests'].must_include(pull_request.title)
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
