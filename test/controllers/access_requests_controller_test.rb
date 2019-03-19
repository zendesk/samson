# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe AccessRequestsController do
  include AccessRequestTestSupport

  as_a :viewer do
    around { |t| enable_access_request &t }

    before do
      @request.headers['HTTP_REFERER'] = root_path
    end

    describe '#feature_enabled?' do
      it 'returns true when enabled' do
        assert AccessRequestsController.feature_enabled?
      end

      it 'returns false when disabled' do
        with_env REQUEST_ACCESS_FEATURE: nil do
          refute AccessRequestsController.feature_enabled?
        end
      end
    end

    describe 'GET to #new' do
      describe 'disabled' do
        with_env REQUEST_ACCESS_FEATURE: nil

        it 'renders 404' do
          assert_raises(ActionController::RoutingError) { get :new }
        end
      end

      describe 'enabled' do
        before { get :new }

        it 'renders new template' do
          assert_template :new
        end
      end
    end

    describe 'POST to #create' do
      describe 'disabled' do
        with_env REQUEST_ACCESS_FEATURE: nil

        it 'renders 404' do
          assert_raises(ActionController::RoutingError) { post :create }
        end
      end

      describe 'enabled' do
        let(:manager_email) { 'manager@example.com' }
        let(:reason) { 'Dummy reason.' }
        let(:role) { Role::DEPLOYER }
        let(:request_params) do
          {
            access_request: {
              manager_email: manager_email,
              reason: reason,
              project_ids: Project.all.pluck(:id),
              role_id: role.id,
            },
            redirect_to: '/projects'
          }
        end

        describe 'environment and user' do
          before { post :create, params: request_params }

          it 'sets the pending request flag' do
            assert user.reload.access_request_pending
          end

          it 'sets the flash' do
            flash[:notice].wont_be_nil
          end

          it 'redirects to referrer' do
            assert_redirected_to '/projects'
          end
        end

        it 'invalid access request' do
          request_params[:access_request][:manager_email] = nil
          post :create, params: request_params

          assert_response :unprocessable_entity
          assert_select 'h1', text: 'Request access'
        end

        describe 'email' do
          it 'sends the message' do
            assert_difference 'ActionMailer::Base.deliveries.size', +1 do
              post :create, params: request_params
            end
            access_request_email = ActionMailer::Base.deliveries.last
            access_request_email.cc.must_equal [manager_email, user.email]
            access_request_email.body.to_s.must_match /#{reason}/
            access_request_email.body.to_s.must_match /#{role.display_name}/
            Project.all.each { |project| access_request_email.body.to_s.must_match /#{project.name}/ }
          end
        end
      end
    end
  end
end
