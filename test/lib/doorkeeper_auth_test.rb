# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

class DoorkeeperAuthTestingController < ActionController::Base
  include DoorkeeperAuth
  api_accessible! true

  def foo
    raise "Foo Controller"
  end
end

describe DoorkeeperAuthTestingController do
  use_test_routes

  subject { proc { get :foo, test_route: true } }

  describe 'when winning_strategy is not doorkeeper' do
    before do
      request.env['warden'].stubs(:winning_strategy).returns(:basic)
    end

    it 'allows access' do
      subject.must_raise(RuntimeError)
    end
  end

  describe 'when winning_strategy is doorkeeper' do
    describe 'for disallowed controllers' do
      before do
        DoorkeeperAuthTestingController.stubs(:api_accessible).returns(false)
        request.stubs(:fullpath).returns("/testings/foo")
        request.env['warden'].stubs(:winning_strategy).returns(:doorkeeper)
      end

      it 'denies access' do
        subject.must_raise(DoorkeeperAuth::DisallowedAccessError)
      end
    end

    describe 'for allowed controllers' do
      before do
        DoorkeeperAuthTestingController.stubs(:api_accessible).returns(true)
        request.stubs(:fullpath).returns("/api/testings/foo")
        request.env['warden'].stubs(:winning_strategy).returns(:doorkeeper)
      end

      it 'allows access' do
        subject.must_raise(RuntimeError)
      end

      describe 'for non-api paths' do
        before do
          DoorkeeperAuthTestingController.stubs(:api_accessible).returns(true)
          request.stubs(:fullpath).returns("/testings/foo")
          request.env['warden'].stubs(:winning_strategy).returns(:doorkeeper)
        end

        it 'is disallowed' do
          subject.must_raise(DoorkeeperAuth::DisallowedAccessError)
        end
      end
    end
  end
end
