require_relative '../test_helper'

describe ProjectsHelper do
  describe "#star_link" do
    let(:project) { projects(:test) }
    let(:current_user) { users(:admin) }

    it "star a project" do
      current_user.stubs(:starred_project?).returns(false)
      link =  star_for_project(project)
      assert_includes link, %{href="/stars?id=#{project.to_param}"}
      assert_includes link, %{data-method="post"}
    end

    it "unstar a project" do
      current_user.stubs(:starred_project?).returns(true)
      link =  star_for_project(project)
      assert_includes link, %{href="/stars/#{project.to_param}"}
      assert_includes link, %{data-method="delete"}
    end
  end

  describe "#github_ok?" do
    let(:status_url) { "https://#{Rails.application.config.samson.github.status_url}/api/status.json" }

    describe "with an OK response" do
      before do
        stub_request(:get, status_url).to_return(
          :headers => { :content_type => 'application/json' },
          :body => JSON.dump(:status => 'good')
        )
      end

      it 'returns ok and caches' do
        assert_equal true, github_ok?
        assert_equal true, Rails.cache.read(github_status_cache_key)
      end
    end

    describe "with a bad response" do
      before do
        stub_request(:get, status_url).to_return(
          :headers => { :content_type => 'application/json' },
          :body => JSON.dump(:status => 'bad')
        )
      end

      it 'returns false and does not cache' do
        assert_equal false, github_ok?
        assert_nil Rails.cache.read(github_status_cache_key)
      end
    end

    describe "with an invalid response" do
      before do
        stub_request(:get, status_url).to_return(:status => 400)
      end

      it 'returns false and does not cache' do
        assert_equal false, github_ok?
        assert_nil Rails.cache.read(github_status_cache_key)
      end
    end

    describe "with a timeout" do
      before do
        stub_request(:get, status_url).to_timeout
      end

      it 'returns false and does not cache' do
        assert_equal false, github_ok?
        assert_nil Rails.cache.read(github_status_cache_key)
      end
    end
  end
end
