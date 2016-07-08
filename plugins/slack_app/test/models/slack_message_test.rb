require_relative '../test_helper'

SingleCov.covered!

describe SlackMessage do
  let(:deploy) { deploys(:succeeded_test) }
  let(:msg) { SlackMessage.new deploy }
  let(:body) { msg.message_body }
  let(:deployer) { users(:deployer) }
  let(:deployer_buddy) { users(:deployer_buddy) }
  let(:deployer_identifier) { slack_identifiers(:deployer) }
  let(:deployer_buddy_identifier) { slack_identifiers(:deployer_buddy) }
  before do
    deployer_identifier.update_column(:user_id, deploy.user.id)
    deployer_buddy_identifier.update_column(:user_id, deployer_buddy.id)
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

      it 'has no buttons' do
        assert_nil body[:attachments]
      end

      it 'mentions both users when the deploy has a buddy' do
        deploy.stubs(:buddy).returns(deployer_buddy)
        body[:text].must_include deployer_identifier.identifier
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
        body[:text].must_include deployer_identifier.identifier
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
        DeployResponseUrl.create! deploy_id: deploy.id, response_url: 'http://example.com/xyz'
        stub_request(:post, 'http://example.com/xyz').
        with(body: /successfully deployed/)
      end

      it 'sends a request to the response URL' do
        msg.deliver
      end
    end
  end
end
