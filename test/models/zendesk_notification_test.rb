require 'test_helper'

describe ZendeskNotification do
  let(:stage) { stub(name: "Production")}
  let(:changeset) { stub_everything(commits: ["ZD#18 this fixes a very bad bug"], zendesk_tickets: [18]) }
  let(:deploy) { stub(changeset: changeset) }
  let(:notification) { ZendeskNotification.new(stage, deploy) }
  let(:api_response_headers) { {:headers => {:content_type => "application/json"}} }

  describe 'when commit messages include Zendesk tickets' do
    it "comments on the ticket when comment is not already added" do
      ZendeskNotification.any_instance.stubs(:is_comment_added?).returns(false)
      ticket = stub_api_request(:get, "api/v2/tickets/18")

      comment = stub_api_request(:put, "api/v2/tickets/18").
                  with(:body => "{\"ticket\":{\"comment\":{\"value\":\"A fix for this issue has been deployed to Production\",\"public\":false}}}")

      notification.deliver

      assert_requested ticket
      assert_requested comment
    end

    it "does not update the ticket when comment is not already added" do
      ZendeskNotification.any_instance.stubs(:is_comment_added?).returns(true)
      ticket = stub_api_request(:get, "api/v2/tickets/18")

      comment = stub_api_request(:get, "api/v2/tickets/18").
                  with(:body => "{\"ticket\":{\"comment\":{\"value\":\"A fix for this issue has been deployed to Production\",\"public\":false}}}")

      notification.deliver

      assert_requested ticket
      assert_not_requested comment
    end
  end

  private

  def stub_api_request(method, path)
    token = ENV['CLIENT_SECRET']
    user = ENV['ZENDESK_USER']
    url = ENV['ZENDESK_URL'].split('//')[1]
    body = '{ "ticket": { "id": 18, "comment": {"value": "Comment body", "public": true }}}'

    stub_request(method, "https://#{user}%2Ftoken:#{token}@#{url}/#{path}").
      with(:headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'ZendeskAPI API 1.3.4'}).
      to_return(api_response_headers.merge(:status => 200, :body => body))
  end
end
