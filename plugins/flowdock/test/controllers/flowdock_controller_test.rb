require_relative '../test_helper'

SingleCov.covered!

describe FlowdockController do
  let(:token) { 'asdkjh21s' }

  before { ENV['FLOWDOCK_API_TOKEN'] = token }
  after { ENV.delete 'FLOWDOCK_API_TOKEN' }

  as_a_viewer do
    describe 'users' do
      let(:flowdock_users) do
        1.upto(3).map { |i| flowdock_user(i) }
      end

      describe 'flowdock token available' do
        before do
          Flowdock::Client.any_instance.expects(:get).with('/users').returns(flowdock_users)
        end

        it 'returns the list of flowdock users' do
          get :users
          assert_response :success
          fetched_users = JSON.parse(response.body)['users']
          fetched_users.size.must_equal(3)
          fetched_users.each do |user|
            %w[id name avatar type].must_equal(user.keys)
          end
        end
      end

      describe 'flowdock token not available' do
        before do
          SamsonFlowdock::FlowdockService.any_instance.stubs(:flowdock_api_token).returns(nil)
        end

        it 'returns a 404' do
          get :users
          assert_response :not_found
        end
      end
    end

    describe 'buddy request notifications' do
      it 'sends a buddy request' do
        FlowdockNotification.any_instance.expects(:buddy_request).once
        deploy_id = deploys(:succeeded_test).id
        post :notify, deploy_id: deploy_id, message: 'Test', authenticity_token:  set_form_authenticity_token
        assert_response :success
      end

      it 'renders 404 as json' do
        post :notify, deploy_id: 112212112
        assert_response :not_found
        response.body.must_match /{\"message\":\"Couldn't find Deploy with 'id'=112212112/
      end
    end
  end

  def flowdock_user(i)
    {
      'id' => i,
      'nick' => "nickname#{i}",
      'avatar' => "avatar#{i}",
      'type' => "type#{i}"
    }
  end
end
