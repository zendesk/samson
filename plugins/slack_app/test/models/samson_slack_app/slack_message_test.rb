# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe SamsonSlackApp::SlackMessage do
  let(:deploy) { deploys(:succeeded_test) }
  let(:msg) { SamsonSlackApp::SlackMessage.new deploy }
  let(:body) { msg.message_body }
  let(:super_admin) { users(:super_admin) }
  let(:deployer_buddy) { users(:deployer_buddy) }
  let(:super_admin_identifier) { samson_slack_app_slack_identifiers(:super_admin) }
  let(:deployer_buddy_identifier) { samson_slack_app_slack_identifiers(:deployer_buddy) }

  before do
    deploy.changeset.stubs(:pull_requests).returns([])
  end

  describe '#message_body' do
    describe 'waiting for a buddy' do
      def add_prs
        deploy.changeset.stubs(:pull_requests).returns(
          [
            stub(
              url: 'http://example.com/pr1',
              number: '12345',
              title: 'Foo the Bars',
              risks: nil
            ),
            stub(
              url: 'http://example.com/pr2',
              number: '23456',
              title: 'Baz the Flibbutzes',
              risks: nil
            )
          ]
        )
      end

      def add_prs_with_risk
        deploy.changeset.stubs(:pull_requests).returns(
          [
            stub(
              url: 'http://example.com/pr1',
              number: '12345',
              title: 'Foo the Bars',
              risks: '- Kittens'
            ),
            stub(
              url: 'http://example.com/pr2',
              number: '23456',
              title: 'Baz the Flibbutzes',
              risks: '- Puppies'
            )
          ]
        )
      end

      before do
        deploy.stubs(:waiting_for_buddy?).returns(true)
      end

      it 'includes a 👍 button' do
        body[:attachments][0][:actions][0][:text].must_include ':+1: Approve'
      end

      it 'describes a deploy with no PRs' do
        body[:text].must_include deploy.stage.name
        body[:text].must_include deploy.project.name
        body[:attachments][0][:fields][0][:value].must_equal '(no PRs)'
        body[:attachments][0][:fields][1][:value].must_equal '(no risks)'
      end

      it 'describes a deploy with PRs and no risks' do
        add_prs
        body[:attachments][0][:fields][0][:value].must_include 'Foo the Bars'
        body[:attachments][0][:fields][1][:value].must_equal '(no risks)'
      end

      it 'describes a deploy with risky PRs' do
        add_prs_with_risk
        body[:attachments][0][:fields][0][:value].must_include 'Foo the Bars'
        body[:attachments][0][:fields][1][:value].must_include 'Kittens'
        body[:attachments][0][:fields][1][:value].must_include 'Puppies'
      end
    end

    describe 'during deploy' do
      before { deploy.stubs(:running?).returns(true) }
      before { deploy.stubs(:succeeded?).returns(false) }
      before { deploy.stubs(:waiting_for_buddy?).returns(false) }

      it 'has no buttons' do
        text = "<@Uadmin> is deploying <http://www.test-url.com/projects/foo/deploys/178003093|*Foo* to *Staging*>."
        assert_equal body,
          attachments: [{
            text: 'Deploying…',
            fields: [
              {
                title: "PRs",
                value: "(no PRs)",
                short: true
              }, {
                title: "Risks",
                value: "(no risks)",
                short: true
              }
            ],
            color: 'warning'
          }],
          response_type: 'in_channel',
          text: text
      end

      it 'mentions both users when the deploy has a buddy' do
        deploy.stubs(:buddy).returns(deployer_buddy)
        body[:text].must_include super_admin_identifier.identifier
        body[:text].must_include deployer_buddy_identifier.identifier
      end

      it 'uses email addresses if a user is not attached to slack' do
        user = users(:viewer)
        deploy.stubs(:user).returns(user)
        body[:text].must_include user.email
      end
    end

    describe 'after deploy is finished' do
      it 'says if a deploy failed' do
        deploy.stubs(:failed?).returns(true)
        body[:text].must_include 'failed to deploy'
      end

      it 'says if a deploy errored' do
        deploy.stubs(:errored?).returns(true)
        body[:text].must_include 'failed to deploy'
      end

      it 'says if a deploy succeeded' do
        body[:text].must_include 'successfully deployed'
      end

      it 'mentions both users when the deploy has a buddy' do
        deploy.stubs(:buddy).returns(deployer_buddy)
        body[:text].must_include super_admin_identifier.identifier
        body[:text].must_include deployer_buddy_identifier.identifier
        body[:text].must_include 'successfully deployed'
      end
    end
  end

  describe '#deliver' do
    describe 'with no URL linkage' do
      it 'does not use the network' do
        msg.deliver
      end
    end

    describe 'with a URL linkage' do
      before do
        SamsonSlackApp::DeployResponseUrl.create! deploy_id: deploy.id, response_url: 'http://example.com/xyz'
        stub_request(:post, 'http://example.com/xyz').
          with(body: /successfully deployed/)
      end

      it 'sends a request to the response URL' do
        msg.deliver
      end
    end
  end
end
