# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe "JsonPagination Integration" do
  describe ".add_pagination_links" do
    let(:user) { users(:admin) }
    let(:json) { JSON.parse(@response.body) }

    before { stub_session_auth }

    it "renders without links" do
      get '/locks.json'
      assert_response :success
      json.keys.must_equal ['locks']
    end

    describe "with pagination" do
      before do
        Command.delete_all
        7.times { |x| Command.create(command: "echo #{x}") }
      end

      it "renders with links" do
        get '/commands.json', params: {per_page: 2}
        json.keys.must_equal ['links', 'commands']
        json['links']['last'].must_equal "/commands.json?page=4&per_page=2"
        json['links']['next'].must_equal "/commands.json?page=2&per_page=2"
      end

      it "render with all links" do
        get '/commands.json', params: {per_page: 2, page: 2}
        json['links']['last'].must_equal "/commands.json?page=4&per_page=2"
        json['links']['next'].must_equal "/commands.json?page=3&per_page=2"
        json['links']['first'].must_equal "/commands.json?page=1&per_page=2"
        json['links']['prev'].must_equal "/commands.json?page=1&per_page=2"
      end

      it "includes pagination headers" do
        get '/commands.json', params: {per_page: 2, page: 2}
        headers = @response.headers
        headers["X-PER-PAGE"].must_equal 2
        headers["X-CURRENT-PAGE"].must_equal 2
        headers["X-TOTAL-PAGES"].must_equal 4
        headers["X-TOTAL-RECORDS"].must_equal 7
      end

      it "includes links only if needed" do
        get '/commands.json'
        json.keys.must_equal ['commands']
        headers = @response.headers
        headers["X-TOTAL-PAGES"].must_equal 1
      end
    end
  end
end
