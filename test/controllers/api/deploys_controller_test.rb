require_relative '../../test_helper'

SingleCov.covered!

describe Api::DeploysController do
  let(:redirect_uri) { 'urn:ietf:wg:oauth:2.0:oob' }
  let(:oauth_app) do
    Doorkeeper::Application.new do |app|
      app.name = "Test App"
      app.redirect_uri = redirect_uri
    end
  end

  let(:user) do
    users(:admin)
  end

  let(:token) do
    oauth_app.access_tokens.new do |token|
      token.resource_owner_id = user.id
      token.application_id = oauth_app.id
      token.expires_in = 1000
      token.scopes = 'default'
    end
  end

  describe '#active_count' do
    before do
      Deploy.stubs(:active).returns(['a'])
      token.save
      json!
      auth!("Bearer #{token.token}")
      get :active_count
    end

    it 'responds successfully' do
      assert_response :success
    end

    it 'responds as json' do
      response.content_type.must_equal 'application/json'
    end

    it 'returns as expected' do
      response.body.must_be :==, "1"
    end
  end

  describe 'Doorkeeper Auth Status' do
    subject { @controller }
    it 'is allowed' do
      subject.api_accessible.must_equal true
    end
  end
end
