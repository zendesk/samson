# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe FlowdockController do
  as_a :viewer do
    describe 'buddy request notifications' do
      it 'sends a buddy request' do
        FlowdockNotification.any_instance.expects(:buddy_request).once
        deploy_id = deploys(:succeeded_test).id
        post :notify, params: {deploy_id: deploy_id, message: 'Test'}
        assert_response :success
      end

      it 'fails when deploy is not found' do
        assert_raises ActiveRecord::RecordNotFound do
          post :notify, params: {deploy_id: 112212112}
        end
      end
    end
  end
end
