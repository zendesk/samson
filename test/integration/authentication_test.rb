require_relative '../test_helper'

SingleCov.not_covered!

# need integration in the name for minitest-spec-rails
describe 'Authentication Integration' do
  before do
    stub_request(:get, "https://#{Rails.application.config.samson.github.status_url}/api/status.json").to_timeout
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
end
