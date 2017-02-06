# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Integrations::BaseController do
  class BaseTestController < Integrations::BaseController
  end

  tests BaseTestController
  use_test_routes BaseTestController

  let(:sha) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:token) { project.token }

  before do
    project.releases.destroy_all
    project.builds.destroy_all
    Integrations::BaseController.any_instance.stubs(:deploy?).returns(true)
    Integrations::BaseController.any_instance.stubs(:commit).returns(sha)
    Integrations::BaseController.any_instance.stubs(:branch).returns('master')
    Project.any_instance.stubs(:create_release?).returns(true)
    Build.any_instance.stubs(:validate_git_reference).returns(true)
    GitRepository.any_instance.stubs(:fuzzy_tag_from_ref).returns(nil)
    stub_request(:post, "https://api.github.com/repos/bar/foo/releases")
  end

  describe "#create" do
    it 'creates release and no build' do
      post :create, params: {test_route: true, token: token}
      assert_response :success
      project.releases.count.must_equal 1
      project.builds.count.must_equal 0
    end

    it "ignores tags" do
      Integrations::BaseController.any_instance.expects(:branch).returns(nil)
      post :create, params: {test_route: true, token: token}
      assert_response :success
      project.releases.count.must_equal 0
      project.builds.count.must_equal 0
      response.body.must_include "assuming this is a tag"
    end

    it 'does not create a release when latest already includes the commit' do
      GITHUB.expects(:compare).returns(stub(status: 'behind'))
      project.releases.create!(commit: sha.sub('d', 'e'), author: users(:admin))
      post :create, params: {test_route: true, token: token}
      assert_response :success
      project.releases.count.must_equal 1
    end

    describe 'when the release branch source is specified' do
      before do
        Project.any_instance.unstub(:create_release?)
        project.update_column(:release_branch, 'master')
      end

      Samson::Integration::SOURCES.each do |release_source|
        it 'creates a release if the source matches' do
          project.update_column(:release_source, release_source)
          Integrations::BaseController.any_instance.stubs(:service_name).returns(release_source)
          post :create, params: {test_route: true, token: token}
          assert_response :success
          project.releases.count.must_equal 1
        end

        it 'does not create a release if the source does not match' do
          project.update_column(:release_source, 'none')
          Integrations::BaseController.any_instance.stubs(:service_name).returns(release_source)
          post :create, params: {test_route: true, token: token}
          assert_response :success
          project.releases.count.must_equal 0
        end
      end
    end

    it 'returns :ok if this is not a merge' do
      Integrations::BaseController.any_instance.stubs(:deploy?).returns(false)
      post :create, params: {test_route: true, token: token}
      assert_response :success
      project.releases.count.must_equal 0
      project.builds.count.must_equal 0
    end

    it 're-uses last release if commit already present' do
      post :create, params: {test_route: true, token: token}
      assert_response :success
      project.releases.count.must_equal 1
      project.builds.count.must_equal 0
    end

    it 'records the request' do
      post :create, params: {test_route: true, token: token}
      assert_response :success
      result = WebhookRecorder.read(project)
      log = <<-LOG.strip_heredoc
        INFO: Branch master is release branch: true
        INFO: Deploying to 0 stages
      LOG
      result.fetch(:log).must_equal log
      result.fetch(:status_code).must_equal 200
      result.fetch(:body).must_equal log
    end

    it 'creates a release and a connected build' do
      Project.any_instance.stubs(:build_docker_image_for_branch?).returns(true)

      post :create, params: {test_route: true, token: token}

      assert_response :success
      project.reload
      project.releases.count.must_equal 1
      project.builds.count.must_equal 1
      project.builds.first.releases.must_equal project.releases
    end

    it "fails with invalid token" do
      post :create, params: {test_route: true, token: token + 'x'}
      assert_response :unauthorized
    end

    it 'does not blow up when creating docker image if a release was not created' do
      Project.any_instance.expects(create_release?: false)
      Project.any_instance.expects(build_docker_image_for_branch?: true)

      post :create, params: {test_route: true, token: token}

      assert_response :success
      project.reload
      project.releases.count.must_equal 0
      project.builds.count.must_equal 1
    end

    describe "when deploy hooks are setup" do
      before do
        project.webhooks.create!(branch: 'master', stage: stage, source: 'any')
        project.webhooks.create!(branch: 'master', stage: stages(:test_production), source: 'any')
      end

      it "stops deploy to further stages when first fails" do
        DeployService.any_instance.expects(:deploy!).times(1).returns(Deploy.new)
        post :create, params: {test_route: true, token: token}
        assert_response :unprocessable_entity
      end

      it 'uses the release version to make the deploy easy to understand' do
        post :create, params: {test_route: true, token: token}
        assert_response :success
        Deploy.first.reference.must_equal 'v1'
      end

      it 'uses the commit to make the deploy when no release was created' do
        Project.any_instance.stubs(:create_release?).returns(false)
        post :create, params: {test_route: true, token: token}
        assert_response :success
        Deploy.first.reference.must_equal sha
      end
    end
  end

  describe "#commit" do
    it "raises when not implemented" do
      Integrations::BaseController.any_instance.unstub(:commit)
      assert_raises(NotImplementedError) { @controller.send(:commit) }
    end
  end

  describe "#deploy?" do
    it "raises when not implemented" do
      Integrations::BaseController.any_instance.unstub(:deploy?)
      assert_raises(NotImplementedError) { @controller.send(:deploy?) }
    end
  end

  describe "#contains_skip_token?" do
    it "recognizes skips" do
      assert @controller.send(:contains_skip_token?, "[skip deploy] docs change")
      assert @controller.send(:contains_skip_token?, "[deploy skip] docs change")
    end

    it "does not recognize normal deploys" do
      refute @controller.send(:contains_skip_token?, "do not skip deploy")
    end
  end

  it "does not use Rails.logger, but record_log in all subclasses so logs are always visible to end users" do
    bad = Dir['{,plugins/*/}app/controllers/integrations/*'].select do |file|
      File.read(file) =~ /\blogger\b/
    end
    bad.delete('app/controllers/integrations/base_controller.rb')
    bad.must_equal [], "#{bad.join(', ')} include Rails.logger calls, use record_log"
  end
end
