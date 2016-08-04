require_relative '../test_helper'

# need to manually load GithubAuthorization class
require_relative '../../lib/omniauth/github_authorization'

SingleCov.covered!

class SessionsControllerTest < ActionDispatch::IntegrationTest
  before { OmniAuth.config.logger }
  describe "#new" do
    describe "when logged in" do
      before do
        login_as(users(:admin))
        get login_path
      end

      it "redirects to the root url" do
        assert_redirected_to root_path
      end
    end

    describe "when not logged in" do
      before do
        get login_path
      end

      it "renders" do
        assert_template :new
      end
    end
  end

  describe "omniauth callbacks" do
    let(:headers) { {} }
    let(:strategy) { {} }
    let(:user) { users(:viewer) }
    let(:uid) { 4 }

    before { OmniAuth.config.test_mode = true }
    after { OmniAuth.config.mock_auth[strategy] = nil }

    describe "#github" do
      let(:user) { users(:github_viewer) }
      let(:strategy) { :github }
      let(:uid) { user.external_id[/\d/] }
      let(:role_id) { Role::VIEWER.id }

      before do
        GithubAuthorization.any_instance.stubs(role_id: role_id)

        # Replaces old @request.env[omniauth.auth] and strategy code
        OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
          provider: strategy.to_s,
          uid: uid,
          info: {
            name: user.name,
            email: user.email
          },
          extra: {
            raw_info: {
              login: 'xyz'
            }
          }
        )

        get '/auth/github', headers: headers
        follow_redirect!
      end

      it 'logs the user in' do
        @controller.send(:current_user).must_equal(user)
      end

      it 'redirects to the root path' do
        assert_redirected_to root_path
      end

      describe 'with an origin' do
        let(:headers) { { 'HTTP_REFERER' => '/hello' } }

        it 'redirects to /hello' do
          assert_redirected_to '/hello'
        end
      end

      describe 'without organization access' do
        let(:role_id) { nil }

        it 'is not allowed to view anything' do
          @controller.send(:current_user).must_be_nil
          assert_template :new
          request.flash[:error].wont_be_nil
        end
      end

      describe 'with invalid role' do
        let(:uid) { 123 } # force new user
        let(:role_id) { 1234 } # make new user invalid

        it 'does not log in' do
          assert flash[:error]
          @controller.send(:current_user).must_equal(nil)
          assert_redirected_to root_path
        end
      end
    end

    def self.omniauth_callback_email_test(strategy_symbol, method = :get)
      describe "##{strategy_symbol}" do
        let(:strategy) { strategy_symbol }

        before do
          user.update_column(:external_id, "#{strategy}-#{uid}")
          OmniAuth.config.mock_auth[strategy] = OmniAuth::AuthHash.new(
            provider: strategy.to_s,
            uid: uid,
            info: {
              name: user.name,
              email: user.email
            }
          )
        end

        describe 'without email restriction' do
          before do
            SessionsController.any_instance.stubs(:restricted_email_domain).returns(nil)
            get "/auth/#{strategy_symbol}", headers: headers
            method == :get ? follow_redirect! : post(response.location)
          end

          it 'logs the user in' do
            @controller.send(:current_user).must_equal(user)
          end

          it 'redirects to the root path' do
            assert_redirected_to root_path
          end

          describe 'with an origin' do
            let(:headers) { { 'HTTP_REFERER' => '/hello' } }

            it 'redirects to /hello' do
              assert_redirected_to '/hello'
            end
          end
        end

        describe 'with email restriction' do
          before do
            SessionsController.any_instance.stubs(:restricted_email_domain).returns("@uniqlo.com")
            get "/auth/#{strategy_symbol}"
            method == :get ? follow_redirect! : post(response.location)
          end

          it 'does not log the user in' do
            @controller.send(:current_user).must_be_nil
          end

          it 'renders' do
            assert_template :new
          end

          it 'sets a flash error' do
            request.flash[:error].wont_be_nil
          end
        end
      end
    end

    omniauth_callback_email_test :google
    omniauth_callback_email_test :gitlab
    omniauth_callback_email_test :ldap, :post
  end

  describe "#failure" do
    before do
      get auth_failure_path
    end

    it "redirects to the root url" do
      assert_redirected_to root_path
    end

    it "sets a flash error" do
      request.flash[:error].wont_be_nil
    end
  end

  describe "#destroy" do
    before do
      login_as(users(:admin))
      get logout_path
    end

    it "removes the user_id" do
      session.to_hash.except("flash").must_be_empty
    end

    it "redirects to the root url" do
      assert_redirected_to root_path
    end

    it "sets a flash notice" do
      request.flash[:notice].wont_be_nil
    end
  end
end
