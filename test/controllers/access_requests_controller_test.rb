require_relative '../test_helper'

SingleCov.covered!

describe AccessRequestsController do
  include AccessRequestTestSupport
  as_a_viewer do
    before do
      enable_access_request
      @request.headers['HTTP_REFERER'] = root_path
    end

    after { restore_access_request_settings }

    describe '#feature_enabled?' do
      it 'returns true when enabled' do
        assert AccessRequestsController.feature_enabled?
      end

      it 'returns false when disabled' do
        ENV['REQUEST_ACCESS_FEATURE'] = nil
        refute AccessRequestsController.feature_enabled?
      end
    end

    describe 'GET to #new' do
      describe 'disabled' do
        before { ENV['REQUEST_ACCESS_FEATURE'] = nil }

        it 'raises an exception' do
          assert_raises(ActionController::RoutingError) { get :new }
        end
      end

      describe 'enabled' do
        before { get :new }

        it 'renders new template' do
          assert_template :new
        end

        it 'stores the referrer' do
          session[:access_request_back_to].must_equal root_path
        end
      end
    end

    describe 'POST to #create' do
      describe 'disabled' do
        before { ENV['REQUEST_ACCESS_FEATURE'] = nil }

        it 'raises an exception' do
          assert_raises(ActionController::RoutingError) { post :create }
        end
      end

      describe 'enabled' do
        let(:manager_email) { 'manager@example.com' }
        let(:reason) { 'Dummy reason.' }
        let(:role) { Role::DEPLOYER }
        let(:request_params) do
          {manager_email: manager_email, reason: reason, project_ids: Project.all.pluck(:id), role_id: role.id}
        end
        let(:session_params) { {access_request_back_to: root_path} }
        describe 'environment and user' do
          before { post :create, request_params, session_params }

          it 'sets the pending request flag' do
            assert @controller.send(:current_user).access_request_pending
          end

          it 'sets the flash' do
            flash[:success].wont_be_nil
          end

          it 'clears the session' do
            session.wont_include :access_request_back_to
          end

          it 'redirects to referrer' do
            assert_redirected_to root_path
          end
        end

        describe 'email' do
          it 'sends the message' do
            assert_difference 'ActionMailer::Base.deliveries.size', +1 do
              post :create, request_params, session_params
            end
            access_request_email = ActionMailer::Base.deliveries.last
            access_request_email.cc.must_equal [manager_email]
            access_request_email.body.to_s.must_match /#{reason}/
            access_request_email.body.to_s.must_match /#{role.display_name}/
            Project.all.each { |project| access_request_email.body.to_s.must_match /#{project.name}/ }
          end
        end
      end
    end
  end
end
