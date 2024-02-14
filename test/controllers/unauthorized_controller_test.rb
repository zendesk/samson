# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe 'Unauthorized' do
  include Rack::Test::Methods

  def app
    UnauthorizedController
  end

  describe '#respond' do
    def request(params: {})
      get path, {controller: "ping", action: "show"}.merge(params), headers
    end

    describe 'as html' do
      alias_method :response, :last_response
      let(:headers) { {} }
      let(:path) { '/' }
      let(:flash) { last_request.env['action_dispatch.request.flash_hash'] }

      it 'redirects to the login path' do
        request
        response.status.must_equal 302

        # Really just a path, but Rack insists on using the full SERVER_NAME
        response.headers['Location'].must_equal('http://example.org/login?redirect_to=%2Fping')
      end

      it 'sets the flash' do
        request
        flash[:alert].must_equal 'You are not logged in. '
      end

      describe 'when user is not authorized' do
        let(:headers) { {'warden' => stub(user: User.new)} }

        it 'uses a custom flash message for viewing' do
          request
          flash[:alert].must_equal 'You are not authorized to view this page. '
        end

        it 'uses a custom flash message for changes' do
          request(params: {_method: "patch"})
          flash[:alert].must_equal "You are not authorized to make this change. "
        end

        describe "with request access" do
          with_env REQUEST_ACCESS_FEATURE: 'true'

          it "adds link" do
            request(params: {_method: "patch"})
            flash[:alert].must_equal(
              "You are not authorized to make this change." \
              " <a href=\"/access_requests/new\">Request additional access rights</a>"
            )
            assert flash[:alert].html_safe?
          end

          it "does not add link when user already requested" do
            headers['warden'].user.access_request_pending = true
            request(params: {_method: "patch"})
            flash[:alert].must_equal "You are not authorized to make this change. Access request pending."
          end
        end
      end

      describe "with api" do
        let(:path) { "deploys/active_count.json" }

        it 'responds unauthorized' do
          request
          response.status.must_equal 401
        end

        it 'responds with json' do
          request
          response.headers['Content-Type'].must_match(%r{\Aapplication/json})
        end
      end

      describe 'with a referer' do
        let(:headers) { {'HTTP_REFERER' => '/hello'} }

        it 'redirects to the login path' do
          request
          response.status.must_equal 302

          # Really just '/', but Rack insists on using the full SERVER_NAME
          response.headers['Location'].must_equal('http://example.org/login?redirect_to=%2Fping')
        end
      end
    end

    describe 'as json' do
      before do
        get '/', format: :json
      end

      it 'responds unauthorized' do
        last_response.status.must_equal 401
      end

      it 'responds with json' do
        last_response.headers['Content-Type'].must_match(%r{\Aapplication/json})
      end
    end

    describe 'as unknown content type' do
      it "is fails with Unsupported Media type error" do
        assert_raises ActionController::UnknownFormat do
          get '/', format: :xml
        end
      end
    end
  end
end
