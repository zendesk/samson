# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::PingController do
  oauth_setup!

  before { @request_format = :json }

  as_a_viewer do
    describe "#index" do
      it "succeeds" do
        get :index, format: :json
        assert_response :success
      end
    end
  end
end
