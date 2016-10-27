# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.not_covered!

# needs Integration at the end for minitest-spec-rails
describe 'Authentication Integration' do
  before do
    # UI wants to show github status
    stub_request(:get, "#{Rails.application.config.samson.github.status_url}/api/status.json").to_timeout
  end

  let(:user) { users(:admin) }

  it "lets 401s get out to inform users of real error causes" do
    post "/oauth/token"
    assert_response :unauthorized
    response.body.must_include "{\"error\":\"invalid_request\""
  end

  describe 'session request' do
    before do
      Warden::SessionSerializer.any_instance.stubs(:session).returns("warden.user.default.key" => user.id)
    end

    it "uses the user stored in the sesion" do
      get '/'
      assert_response :success
    end

    it "fails when no user is in the session" do
      Warden::SessionSerializer.any_instance.unstub(:session)
      get '/'
      assert_response :redirect
    end

    it "fails when user logged in too long ago" do
      user.update_column :last_login_at, 1.year.ago
      get '/'
      assert_response :redirect
    end

    it "fails when user never logged in, to log out legacy users" do
      user.update_column :last_login_at, nil
      get '/'
      assert_response :redirect
    end
  end

  describe 'doorkeeper flow' do
    let(:redirect_uri) { 'urn:ietf:wg:oauth:2.0:oob' }
    let!(:oauth_app) do
      Doorkeeper::Application.create! do |app|
        app.name = "Test App"
        app.redirect_uri = redirect_uri
      end
    end
    let(:params) do
      { client_id: oauth_app.uid, redirect_uri: redirect_uri, state: "", response_type: "code", scope: "" }
    end

    describe 'when not logged in' do
      it 'redirects to login page' do
        get "/oauth/authorize", params: params
        response.location.must_match %r{/login}
        assert_response :redirect
      end
    end

    describe 'when logged in' do
      before do
        login_as(users(:super_admin))
        get "/oauth/authorize", params: params
      end

      it 'redirects to' do
        assert_response :success
        response.body.must_match %r{Authorization required}
      end

      describe 'getting code' do
        before do
          post '/oauth/authorize', params: params
        end

        it 'redirects' do
          assert_response :redirect
        end

        it 'includes a code' do
          code = oauth_app.access_grants.first
          code.redirect_uri.must_equal redirect_uri
          code.application_id.must_equal oauth_app.id
          code = code.token
          response.location.must_match %r{#{code}}
        end

        describe 'getting the token' do
          let(:new_params) do
            {
              client_id: oauth_app.uid,
              client_secret: oauth_app.secret,
              code: oauth_app.access_grants.first.token,
              grant_type: "authorization_code",
              redirect_uri: redirect_uri
            }
          end

          before do
            post "/oauth/token", params: new_params
          end

          it 'returns a json blob' do
            response.content_type.must_equal 'application/json'
          end

          it 'has an access token' do
            JSON.parse(response.body)['access_token'].must_equal oauth_app.access_tokens.first.token
          end
        end
      end
    end
  end
end
