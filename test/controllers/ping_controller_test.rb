require_relative '../test_helper'

describe PingController do
  describe 'GET to #show' do
    setup { get :show }

    it 'responds ok' do
      response.status.must_equal(200)
    end
  end
end
