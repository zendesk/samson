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

      before do
        get '/', {}, headers
      end

      it 'sets the flash' do
        flash = last_request.env['action_dispatch.request.flash_hash']
        flash[:authorization_error].must_equal('You are not authorized to view this page.')
      end

      describe 'without a referer' do
        it 'redirects to the login path' do
          last_response.must_be(:redirect?)

          # Really just '/', but Rack insists on using the full SERVER_NAME
          last_response.headers['Location'].must_equal('http://example.org/login')
        end
      end

      describe 'with a referer' do
        let(:headers) { { 'HTTP_REFERER' => '/hello' } }

        it 'redirects to the referer' do
          last_response.must_be(:redirect?)
          last_response.headers['Location'].must_equal("http://example.org/hello")
        end
      end
    end

    describe 'as json' do
      before do
        get '/', format: :json
      end

      it 'responds not found' do
        last_response.must_be(:not_found?)
      end

      it 'responds with json' do
        last_response.headers['Content-Type'].must_match(%r{\Aapplication/json})
      end
    end
  end
end
