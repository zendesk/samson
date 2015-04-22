require_relative '../test_helper'

describe ZendeskNotification do
  def commit(message)
    Changeset::Commit.new(nil, Hashie::Mash.new(commit: {message: message}))
  end

  let(:stage) { stub(name: "Production")}
  let(:user) { stub(email: "deploys@example.org")}
  let(:changeset) { stub("changeset", commits: [commit("ZD#18 this fixes a very bad bug")]) }
  let(:deploy) { stub(changeset: changeset, user: user, stage: stage) }
  let(:notification) { ZendeskNotification.new(deploy) }
  let(:api_response_headers) { {:headers => {:content_type => "application/json"}} }

  describe 'when commit messages include Zendesk tickets' do
    before do
      ZendeskNotificationRenderer.stubs(:render).returns("A fix to project has been deployed to Production. Deploy details: v2.14")
    end

    it "comments on the ticket" do
      comment = stub_api_request(:put, "api/v2/tickets/18").
        with(:body => "{\"ticket\":{\"status\":\"open\",\"comment\":{\"value\":\"A fix to project has been deployed to Production. Deploy details: v2.14\",\"public\":false}}}")

      notification.deliver

      assert_requested comment
    end
  end

  describe "#zendesk_tickets" do
    let(:notification) { ZendeskNotification.new(deploy) }

    it "returns a list of Zendesk tickets mentioned in commit messages" do
      commits = [
        commit("ZD#1234 this fixes a very bad bug"),
        commit("ZD4567 Fix typo")
      ]
      notification.send(:zendesk_tickets, commits).must_equal [1234, 4567]
    end

    it "returns an empty array if there are no ticket references" do
      commit = commit("Fix build error")
      notification.send(:zendesk_tickets, [commit]).must_equal []
    end
  end

  private

  def stub_api_request(method, path)
    url = ENV['ZENDESK_URL']
    body = '{ "ticket": { "id": 18, "comment": {"value": "Comment body", "public": true }, "status": "open"}}'

    stub_request(method, "#{url}/#{path}").to_return(api_response_headers.merge(:status => 200, :body => body))
  end
end
