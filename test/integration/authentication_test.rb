# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.not_covered!

# needs Integration at the end for minitest-spec-rails
describe 'Authentication Integration' do
  let(:user) { users(:admin) }

  it "lets 401s get out to inform users of real error causes" do
    get "/oauth/applications.json"
    assert_response :unauthorized
    response.body.must_include "{\"error\":\"You are not logged in"
  end

  describe 'session request' do
    before { stub_session_auth }

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

  describe 'last_seen_at' do
    def perform_get(authorization)
      get "/", headers: {HTTP_AUTHORIZATION: authorization}
    end

    let(:valid_header) do
      token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, scopes: 'default')
      "Bearer #{token.token}"
    end

    before { user.update_column(:last_seen_at, 1.minute.ago) }

    it "updates last_seen_at when it was unset" do
      user.update_column(:last_seen_at, nil)
      perform_get valid_header
      user.reload.last_seen_at.must_be :>, 3.seconds.ago
    end

    it "updates last_seen_at when it was old" do
      user.update_column(:last_seen_at, 1.day.ago)
      perform_get valid_header
      user.reload.last_seen_at.must_be :>, 3.seconds.ago
    end

    it "does not update last_seen_at when it was current, to avoid db overhead" do
      perform_get valid_header
      user.reload.last_seen_at.must_be :<, 10.seconds.ago
    end

    it "does not update last_seen_at when login failed" do
      perform_get valid_header + Base64.encode64('foo')
      user.reload.last_seen_at.must_be :<, 10.seconds.ago
    end

    it "updates last_seen_at when using an existing session" do
      user.update_column(:last_seen_at, nil)
      stub_session_auth
      perform_get ''
      user.reload.last_seen_at.must_be :>, 3.seconds.ago
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
      {client_id: oauth_app.uid, redirect_uri: redirect_uri, state: "", response_type: "code", scope: ""}
    end

    describe 'when not logged in' do
      it 'redirects to login page' do
        get "/oauth/authorize", params: params
        assert_redirected_to %r{/login}
      end
    end

    describe 'when logged in' do
      before { login_as(users(:super_admin)) }

      it 'renders' do
        get "/oauth/authorize", params: params
        assert_response :success
        response.body.must_include "Authorization required"
      end

      describe 'getting code' do
        before do
          post '/oauth/authorize', params: params
        end

        it 'includes a code' do
          code = oauth_app.access_grants.first
          code.redirect_uri.must_equal redirect_uri
          code.application_id.must_equal oauth_app.id
          assert_redirected_to /#{code.token}/
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

          it 'has an access token' do
            post "/oauth/token", params: new_params
            response.media_type.must_equal 'application/json'
            JSON.parse(response.body)['access_token'].must_equal oauth_app.access_tokens.first.token
          end
        end
      end
    end
  end
end
