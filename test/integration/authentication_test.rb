# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.not_covered!

# need integration in the name for minitest-spec-rails
describe 'Authentication Integration' do
  before do
    stub_request(:get, "#{Rails.application.config.samson.github.status_url}/api/status.json").to_timeout
  end

  let(:user) { users(:admin) }

  describe 'basic authentication' do
    let(:path) { '/' }

    before do
      get path, {}, 'HTTP_AUTHORIZATION' => authorization
    end

    describe 'successful' do
      let(:authorization) do
        "Basic #{Base64.encode64(user.email + ':' + user.token)}"
      end

      it 'is successful' do
        response.status.must_equal(200)
      end

      it 'does not set cookies' do
        response.headers['Set-Cookie'].must_be_nil
      end
    end

    describe 'unsuccessful' do
      let(:authorization) do
        "Basic #{Base64.encode64(user.email + ':123' + user.token)}"
      end

      it 'is unauthorized' do
        response.status.must_equal(302)
      end

      describe 'json' do
        let(:path) { '/projects.json' }

        it 'is not found' do
          response.status.must_equal(404)
        end
      end
    end

    describe 'not Basic' do
      let(:authorization) do
        "Bearer #{Base64.encode64(user.email + ':123' + user.token)}"
      end

      it 'redirects' do
        response.status.must_equal(302)
      end
    end
  end

  describe 'session request' do
    describe 'successful' do
      before do
        login_as(user)
        get '/'
      end

      it 'is successful' do
        response.status.must_equal(200)
      end

      it 'sets cookies' do
        response.headers['Set-Cookie'].wont_be_nil
      end
    end

    describe 'unsuccessful' do
      before do
        get '/'
      end

      it 'redirects' do
        response.status.must_equal(302)
      end
    end
  end

  describe 'doorkeeper' do
    let(:redirect_uri) { 'urn:ietf:wg:oauth:2.0:oob' }
    let(:oauth_app) do
      Doorkeeper::Application.new do |app|
        app.name = "Test App"
        app.redirect_uri = redirect_uri
      end
    end

    before do
      oauth_app.save
    end

    describe 'when not logged in' do
      it 'redirects to login page' do
        get "/oauth/authorize?client_id=#{oauth_app.uid}&redirect_uri=#{redirect_uri}&response_type=code"
        response.location.must_match %r{/login}
        assert_response :redirect
      end
    end

    describe 'when logged in' do
      before do
        login_as(users(:super_admin))
        get "/oauth/authorize?client_id=#{oauth_app.uid}&redirect_uri=#{redirect_uri}&response_type=code"
      end

      it 'redirects to' do
        assert_response :success
        response.body.must_match %r{Authorization required}
      end

      describe 'getting code' do
        let(:params) do
          { client_id: oauth_app.uid, redirect_uri: redirect_uri, state: "", response_type: "code", scope: "" }
        end

        before do
          post '/oauth/authorize', params
        end

        it 'redirects' do
          assert_response :redirect
        end

        it 'includes a code' do
          code = oauth_app.access_grants.first
          code.redirect_uri.must_be :==, redirect_uri
          code.application_id.must_be :==, oauth_app.id
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
            post "/oauth/token", new_params
          end

          it 'returns a json blob' do
            response.content_type.must_be :==, 'application/json'
          end

          it 'has an access token' do
            JSON.parse(response.body)['access_token'].must_be :==, oauth_app.access_tokens.first.token
          end

          describe 'using the token to access the api' do
            before do
              logout
              Deploy.stubs(:active).returns(['a'])
            end

            describe 'with a correct token' do
              let(:token) { oauth_app.access_tokens.first.token }
              let(:headers) do
                { "Authorization" => "Bearer #{token}",
                  "Accept" => "application/json",
                  "Content-Type" => "application/json" }
              end

              before do
                get "/api/deploys/active_count", {format: 'json'}, headers
              end

              it 'is successful' do
                assert_response :success
              end

              it 'returns a result' do
                response.body.must_be :==, "1"
              end
            end

            describe 'bad tokens' do
              let(:headers) { {'Authorization' => "Bearer notrealtoken", "Content-Type" => "application/json"} }

              before do
                get '/api/deploys/active_count', {format: 'json'}, headers
              end

              it 'is not successful' do
                response.status.must_be :==, 404
                response.content_type.must_be :==, "application/json"
              end
            end
          end
        end
      end
    end
  end
end
