# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe 'Unauthorized' do
  include Rack::Test::Methods

  def app
    UnauthorizedController
  end

  describe '#respond' do
    describe 'as html' do
      let(:headers) { {} }
      let(:path) { '/' }

      before do
        get path, {}, headers
      end

      it 'sets the flash' do
        flash = last_request.env['action_dispatch.request.flash_hash']
        flash[:authorization_error].must_equal('You are not authorized to view this page.')
      end

      describe "with api" do
        let(:path) { "/api/deploys/active_count.json" }

        it 'responds not found' do
          last_response.status.must_equal 404
        end

        it 'responds with json' do
          last_response.headers['Content-Type'].must_match(%r{\Aapplication/json})
        end
      end

      describe 'without a referer' do
        it 'redirects to the login path' do
          last_response.status.must_equal 302

          # Really just '/', but Rack insists on using the full SERVER_NAME
          last_response.headers['Location'].must_equal('http://example.org/login')
        end
      end

      describe 'with a referer' do
        let(:headers) { { 'HTTP_REFERER' => '/hello' } }

        it 'redirects to the referer' do
          last_response.status.must_equal 302
          last_response.headers['Location'].must_equal("http://example.org/hello")
        end
      end
    end

    describe 'as json' do
      before do
        get '/', format: :json
      end

      it 'responds not found' do
        last_response.status.must_equal 404
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
