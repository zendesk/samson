# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SlackAppHelper do
  describe '#slack_app_oauth_url' do
    it "gives a proper OAuth URL with scopes" do
      with_env SLACK_CLIENT_ID: 'xoxz-slack-client-id' do
        url = slack_app_oauth_url('scope1,scope:two')
        assert 'scope1'.in? url
        assert 'two'.in? url
        assert 'xoxz-slack-client-id'.in? url
      end
    end
  end
end
