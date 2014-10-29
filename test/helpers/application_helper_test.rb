require_relative '../test_helper'

describe ApplicationHelper do
  describe "#deploy_link" do
    let(:project) { projects(:test) }
    let(:stage) { stages(:test_staging) }
    let(:link) { deploy_link(project, stage) }
    let(:current_user) { users(:admin) }

    it "starts a deploy" do
      assert_includes link, ">Deploy<"
      assert_includes link, %{href="/projects/#{project.to_param}/deploys/new?stage_id=#{stage.id}"}
    end

    it "shows locked" do
      stage.stubs(locked_for?: true)
      assert_includes link, ">Locked<"
    end

    it "shows running deploy" do
      deploy = stage.deploys.create!(
        reference: 'master',
        job: Job.create(user: current_user, command: '', project: project)
      )
      stage.stubs(current_deploy: deploy)
      assert_includes link, ">Deploying master...<"
      assert_includes link, %{href="/projects/#{project.to_param}/deploys/#{deploy.id}"}
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
        assert_equal nil, github_ok?
        assert_nil Rails.cache.read(github_status_cache_key)
      end
    end

    describe "with an invalid response" do
      before do
        stub_request(:get, status_url).to_return(:status => 400)
      end

      it 'returns false and does not cache' do
        assert_equal nil, github_ok?
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
