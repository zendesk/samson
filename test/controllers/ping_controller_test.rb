# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe PingController do
  describe 'GET to #show' do
    before { get :show }

    it 'responds ok' do
      response.status.must_equal(200)
    end
  end

  describe 'GET to #error' do
    it 'raises when hit' do
      assert_raises RuntimeError, 'ping#error' do
        get :error
      end
    end
  end
end
