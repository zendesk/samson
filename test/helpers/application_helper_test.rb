require_relative '../test_helper'

describe ApplicationHelper do
  describe "#deploy_link" do
    let(:project) { projects(:test) }
    let(:stage) { stages(:test_staging) }
    let(:link) { deploy_link(project, stage) }
    let(:current_user) { users(:admin) }

    it "starts a deploy" do
      assert_includes link, ">Deploy<"
      assert_includes link, %{href="/projects/#{project.to_param}/stages/#{stage.to_param}/deploys/new"}
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

  describe "#breadcrumb" do
    let(:stage) { stages(:test_staging) }
    let(:project) { projects(:test) }
    let(:environment) { environments(:production) }
    let(:deploy_group) { deploy_groups(:pod1) }

    it "renders strings" do
      breadcrumb("Foobar").must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Foobar</li></ul>"
    end

    it "renders empty" do
      breadcrumb.must_equal "<ul class=\"breadcrumb\"><li class=\"active\">Home</li></ul>"
    end

    it "renders stage" do
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Staging</li></ul>"
    end

    it "renders locked stage" do
      stage.stubs(lock: Lock.new)
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\"><i class=\"glyphicon glyphicon-lock\"></i> Staging</li></ul>"
    end

    it "renders warning stage" do
      stage.stubs(lock: Lock.new(warning: true))
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\"><i class=\"glyphicon glyphicon-warning-sign\"></i> Staging</li></ul>"
    end

    it "renders project" do
      breadcrumb(project).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Project</li></ul>"
    end

    it "renders environment" do
      breadcrumb(environment).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Production</li></ul>"
    end

    it "renders deploy_group" do
      breadcrumb(deploy_group).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Pod1</li></ul>"
    end

    it "renders multiple breadcrumbs" do
      breadcrumb(project, stage, "stuff").must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"\"><a href=\"/projects/foo\">Project</a></li><li class=\"\"><a href=\"/projects/foo/stages/staging\">Staging</a></li><li class=\"active\">stuff</li></ul>"
    end

    it "refuses to render unknown" do
      assert_raises(RuntimeError) { breadcrumb(111) }
    end

    it "does not allow html injection" do
      stage.name = "<script>alert(1)</script>"
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">&lt;script&gt;alert(1)&lt;/script&gt;</li></ul>"
    end
  end
end
