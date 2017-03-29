# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::UsersController do
  oauth_setup!

  before { @request_format = :json }

  as_a_admin do
    unauthorized :delete, :destroy, id: 1, format: :json
  end

  as_a_super_admin do
    describe "#destroy" do
      it "deletes" do
        delete :destroy, params: {id: users(:admin)}, format: :json
        assert_response :success
        assert users(:admin).reload.deleted_at
      end
    end
  end
end
