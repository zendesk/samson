# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::ProjectsController do
  assert_route :get, "/api/projects", to: "api/projects#index"

  oauth_setup!

  describe '#index' do
    before do
      get :index, format: :json
    end

    subject { JSON.parse(response.body) }

    it 'succeeds' do
      assert_response :success
    end

    it 'lists projects' do
      subject.keys.must_equal ['projects']
      keys = subject['projects'].first.keys.sort
      keys.must_equal ["created_at", "id", "name", "owner", "permalink", "repository_url", "url"]
    end
  end
end
