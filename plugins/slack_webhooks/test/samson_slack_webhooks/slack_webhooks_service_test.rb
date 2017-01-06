# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 5

describe SamsonSlackWebhooks::SlackWebhooksService do
  let(:deploy) { deploys(:succeeded_test) }
  let(:service) { SamsonSlackWebhooks::SlackWebhooksService.new }

  before do
    Rails.cache.delete(:slack_users)
  end

  describe '#users' do
    with_env(SLACK_API_TOKEN: 'some-token')

    it "shows all users" do
      stub_request(:post, "https://slack.com/api/users.list").
        to_return(body: {ok: true, members: [{id: 1, name: 'NICK', profile: {image_48: 'AVATAR'}}]}.to_json)
      service.users.must_equal([{id: 1, name: "NICK", avatar: "AVATAR", type: "contact"}])

      # is cached
      service.users.object_id.must_equal service.users.object_id
    end

    it "returns empty users when there's an error" do
      stub_request(:post, "https://slack.com/api/users.list").
        to_return(body: {ok: false, error: "some error"}.to_json)
      Rails.logger.expects(:error).with('Error fetching slack users: some error')
      service.users.must_equal([])

      # is cached
      service.users.object_id.must_equal service.users.object_id
    end

    it "shows nothing when slack fails to fetch users" do
      stub_request(:post, "https://slack.com/api/users.list").to_timeout
      Rails.logger.expects(:error).with(
        'Error fetching slack users (token invalid / service down). Faraday::TimeoutError: execution expired'
      )
      service.users.must_equal([])

      # is cached
      service.users.object_id.must_equal service.users.object_id
    end

    it "shows nothing when api token is not configured" do
      with_env(SLACK_API_TOKEN: nil) do
        Rails.logger.expects(:error).with(
          'Set the SLACK_API_TOKEN env variable to enabled user mention autocomplete.'
        ).twice
        users_1st_time = service.users
        users_1st_time.must_equal([])

        # is not cached
        users_2nd_time = service.users
        users_2nd_time.must_equal([])
        users_2nd_time.object_id.wont_equal users_1st_time.object_id
      end
    end
  end
end
