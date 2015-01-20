require_relative '../../test_helper'

describe Integrations::FlowdockController do

  let(:token) { 'asdkjh21s' }
  let(:headers) { {'Accept'=>'application/json', 'Content-Type'=>'application/json'} }
  before(:all) do
    ENV['FLOWDOCK_API_TOKEN'] = token
  end
  let(:users_endpoint) { "https://#{ENV['FLOWDOCK_API_TOKEN']}:@api.flowdock.com/v1/users"}

  it 'should return the list of flowdock users' do
    delivery = stub_request(:get, users_endpoint)
    get :users
    assert_requested delivery
  end

end
