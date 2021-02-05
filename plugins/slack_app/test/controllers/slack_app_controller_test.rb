# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 3

describe SlackAppController do
  let(:deployer) { users(:deployer) }
  let(:buddy) { users(:deployer_buddy) }
  let(:github_viewer) { users(:github_viewer) }
  let(:admin) { users(:super_admin) }
  let(:deployer_identifier) { samson_slack_app_slack_identifiers(:deployer) }
  let(:buddy_identifier) { samson_slack_app_slack_identifiers(:deployer_buddy) }
  let(:viewer_identifier) { samson_slack_app_slack_identifiers(:github_viewer) }
  let(:admin_identifier) { samson_slack_app_slack_identifiers(:super_admin) }
  let(:body) { JSON.parse @response.body }
  let(:deploy) { deploys(:succeeded_test) }
  let(:project) { projects(:test) }

  def expects_new_deploy
    Changeset.expects(:new).returns(stub(pull_requests: [stub(
      url: 'http://sams.on',
      number: 123,
      title: 'sample PR',
      risks: '- Kittens'
    )]))
  end

  def post_command(id, params = {})
    opts = params.merge(
      token: 'token',
      user_id: id.identifier,
      response_url: 'http://example.com/blah'
    )
    with_env(SLACK_VERIFICATION_TOKEN: 'token') { post :command, params: opts }
  end

  def post_interact(id, params = {})
    opts = params.merge(
      token: 'token',
      user: {id: id.identifier}
    )
    with_env(SLACK_VERIFICATION_TOKEN: 'token') { post :interact, params: opts }
  end

  as_a :viewer do
    describe '#oauth' do
      before do
        stub_request(:post, "https://slack.com/api/oauth.access").
          to_return(status: 200, body: '{"access_token": "iamatoken", "user_id": "Uabcdef"}')
      end

      it 'sends the user to Slack to connect the app' do
        with_env(
          SLACK_CLIENT_ID: 'client-id',
          SLACK_CLIENT_SECRET: 'client-secret',
          SLACK_VERIFICATION_TOKEN: 'token'
        ) { get :oauth }
        @response.body.must_include 'https://slack.com/oauth/authorize?client_id='
        @response.body.must_include '%2Fslack_app%2Foauth'
        @response.body.must_include 'chat%3Awrite%3Abot%2Ccommands%2Cidentify'
      end

      it 'accepts an app token from Slack' do
        with_env SLACK_CLIENT_ID: 'client-id', SLACK_CLIENT_SECRET: 'client-secret' do
          get :oauth, params: {code: 'iamaslackcode'}
        end
        assert SamsonSlackApp::SlackIdentifier.app_token.present?
        identifier = SamsonSlackApp::SlackIdentifier.find_by_user_id users(:github_viewer).id
        identifier.identifier.must_equal 'Ugithubviewer'
      end

      it 'accepts a user token from Slack' do
        SamsonSlackApp::SlackIdentifier.create! identifier: 'i-am-an-app-token'
        with_env SLACK_CLIENT_ID: 'client-id', SLACK_CLIENT_SECRET: 'client-secret' do
          get :oauth, params: {code: 'iamaslackcode'}
        end
        identifier = SamsonSlackApp::SlackIdentifier.find_by_user_id users(:github_viewer).id
        identifier.identifier.must_equal 'Ugithubviewer'
      end
    end
  end

  describe "#command" do
    it "raises if secret token doesn't match" do
      e = assert_raises RuntimeError do
        post :command, params: {token: 'thiswontmatch'}
      end
      e.message.must_equal "Slack token doesn't match SLACK_VERIFICATION_TOKEN"
    end

    describe 'without Slack linkage' do
      it "returns a private error if the user isn't matched up" do
        with_env SLACK_VERIFICATION_TOKEN: 'token' do
          post :command, params: {user_id: 'notconnected', token: nil}
        end
        @response.body.must_include "slack_app/oauth"
      end
    end

    describe 'with Slack linkage' do
      before do
        stub_request(:get, "https://api.github.com/repos/bar/foo/branches/master").
          to_return(status: 200, body: "", headers: {})
      end

      it 'checks the verification token' do
        e = assert_raises do
          post :command, params: {token: 'wups'}
        end
        e.message.must_equal "Slack token doesn't match SLACK_VERIFICATION_TOKEN"
      end

      it 'succeeds on SSL check' do
        post :command, params: {ssl_check: true}
        assert_response :success
        @response.body.must_equal 'ok'
      end

      it 'can deploy with branch and stage' do
        expects_new_deploy
        post_command deployer_identifier, text: "#{project.permalink}/foo/bar to #{project.stages.last.permalink}"
        body['text'].must_include "is deploying"
        deploy = Deploy.first
        deploy.reference.must_equal "foo/bar"
        deploy.stage.permalink.must_equal project.stages.last.permalink
      end

      it 'mentions PRs in the return JSON' do
        expects_new_deploy
        post_command deployer_identifier, text: project.permalink
        first_attachment = body['attachments'][0]
        first_attachment['fields'][0]['value'].must_include '#123'
        first_attachment['fields'][0]['value'].must_include 'sample PR'
      end

      it 'warns on an unauthorized deployer' do
        post_command viewer_identifier, text: project.permalink
      end

      it 'warns on unknown project' do
        post_command deployer_identifier, text: 'jkfldsaklfdsalk'
        @response.body.must_equal "Could not find a project with permalink `jkfldsaklfdsalk`."
      end

      it 'warns on unknown stage' do
        post_command deployer_identifier, text: "#{project.permalink} to unknown"
        @response.body.must_equal "`foo` does not have a stage `unknown`."
      end

      it 'ignores invalid request' do
        post_command deployer_identifier, text: 'wut do I do here'
        @response.body.must_include "Did not understand."
      end
    end
  end

  describe "#interact" do
    it 'says if it cannot find a deploy' do
      with_env(SLACK_VERIFICATION_TOKEN: 'token') { post :interact }
      @response.body.must_include 'Unable to locate this deploy'
    end

    it 'promts the user to connect if user is not connected to Slack' do
      post_interact stub(identifier: 'jkflds'), callback_id: deploy.id
      body['text'].must_include '/slack_app/oauth'
      body['replace_original'].must_equal false
    end

    it 'denies if the user tries to approve their own deploy' do
      post_interact admin_identifier, callback_id: deploy.id
      body['text'].must_include 'cannot approve your own deploys'
    end

    it 'denies if the user cannot approve the deploy' do
      post_interact viewer_identifier, callback_id: deploy.id
      body['text'].must_include 'do not have permissions'
    end

    it 'confirms the deploy on a good approval' do
      Deploy.any_instance.expects(:confirm_buddy!)
      post_interact buddy_identifier, callback_id: deploy.id
    end
  end
end
