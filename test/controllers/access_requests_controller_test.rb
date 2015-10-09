require_relative '../test_helper'

describe AccessRequestsController do
  as_a_viewer do
    before do
      @original_feature_flag = ENV['REQUEST_ACCESS_FEATURE']
      @original_address_list = ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST']
      @original_email_prefix = ENV['REQUEST_ACCESS_EMAIL_PREFIX']
      ENV['REQUEST_ACCESS_FEATURE'] = '1'
      ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'] = 'jira@example.com watchers@example.com'
      ENV['REQUEST_ACCESS_EMAIL_PREFIX'] = 'SAMSON ACCESS'

      @request.headers['HTTP_REFERER'] = root_path
    end

    after do
      ENV['REQUEST_ACCESS_FEATURE'] = @original_feature_flag
      ENV['REQUEST_ACCESS_EMAIL_ADDRESS_LIST'] = @original_address_list
      ENV['REQUEST_ACCESS_EMAIL_PREFIX'] = @original_email_prefix
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
        let(:request_params) { {manager_email: manager_email, reason: reason, project_ids: Project.all.map(&:id)} }
        let(:session_params) { {access_request_back_to: root_path} }
        describe 'environment and user' do
          before { post :create, request_params, session_params }

          it 'sets the pending request flag' do
            assert(@controller.current_user.access_request_pending)
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
            access_request_email.to.must_include manager_email
            access_request_email.body.to_s.must_match /#{reason}/
            Project.all.each { |project| access_request_email.body.to_s.must_match /#{project.name}/ }
          end
        end
      end
    end
  end
end
