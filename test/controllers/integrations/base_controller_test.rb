# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: 5

describe Integrations::BaseController do
  class BaseTestController < Integrations::BaseController
  end

  tests BaseTestController
  use_test_routes BaseTestController

  let(:sha) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }

  before do
    project.releases.destroy_all
    project.builds.destroy_all
    Integrations::BaseController.any_instance.stubs(:deploy?).returns(true)
    Integrations::BaseController.any_instance.stubs(:project).returns(project)
    Integrations::BaseController.any_instance.stubs(:commit).returns(sha)
    Integrations::BaseController.any_instance.stubs(:branch).returns('master')
    Project.any_instance.stubs(:create_releases_for_branch?).returns(true)
    Build.any_instance.stubs(:validate_git_reference).returns(true)
    stub_request(:post, "https://api.github.com/repos/bar/foo/releases").
      to_return(status: 200, body: "", headers: {})
  end

  describe "#create" do
    it 'creates release and build' do
      post :create, params: {test_route: true}
      assert_response :success
      project.releases.count.must_equal 1
      project.builds.count.must_equal 1
    end

    it 'returns :ok if this is not a merge' do
      Integrations::BaseController.any_instance.stubs(:deploy?).returns(false)
      post :create, params: {test_route: true}
      assert_response :success
      project.releases.count.must_equal 0
      project.builds.count.must_equal 0
    end

    it 're-uses last release if commit already present' do
      stub_github_api("repos/bar/foo/compare/#{sha}...#{sha}", status: 'identical')
      post :create, params: {test_route: true}
      assert_response :success

      @controller.expects(:latest_release).once.returns(Minitest::Mock.new.expect(:version, nil))
      post :create, params: {test_route: true}
      assert_response :success
      project.releases.count.must_equal 1
      project.builds.count.must_equal 1
    end

    it 'records the request' do
      post :create, params: {test_route: true}
      assert_response :success
      result = WebhookRecorder.read(project)
      result.fetch(:log).must_equal <<-LOG.strip_heredoc
        INFO: Branch master is release branch: true
        INFO: Starting deploy to all stages
      LOG
      result.fetch(:status_code).must_equal 200
      result.fetch(:body).must_equal ""
    end

    describe 'when creating a docker image' do
      before do
        Project.any_instance.stubs(:build_docker_image_for_branch?).returns(true)
      end

      it 'works' do
        mocked_method = MiniTest::Mock.new
        mocked_method.expect :call, MiniTest::Mock.new.expect(:run!, nil, [Hash]), [Build]
        DockerBuilderService.stub :new, mocked_method do
          post :create, params: {test_route: true}
        end
        assert_response :success
        project.releases.count.must_equal 1
        project.builds.count.must_equal 1
        mocked_method.verify
      end

      describe 'when not creating a release' do
        before do
          Project.any_instance.stubs(:create_releases_for_branch?).returns(false)
        end

        it 'works' do
          mocked_method = MiniTest::Mock.new
          mocked_method.expect :call, MiniTest::Mock.new.expect(:run!, nil, [Hash]), [Build]
          DockerBuilderService.stub :new, mocked_method do
            post :create, params: {test_route: true}
          end
          assert_response :success
          project.releases.count.must_equal 0
          project.builds.count.must_equal 1
          mocked_method.verify
        end
      end
    end
  end

  it "does not use Rails.logger, but record_log in all subclasses so logs are always visible to end users" do
    bad = Dir['app/controllers/integrations/*'].select do |file|
      File.read(file) =~ /\blogger\b/
    end
    bad.delete('app/controllers/integrations/base_controller.rb')
    bad.must_equal [], "#{bad.join(', ')} include Rails.logger calls, use record_log"
  end
end
