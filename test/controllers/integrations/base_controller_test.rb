require_relative '../../test_helper'

SingleCov.covered! uncovered: 8

describe Integrations::BaseController do
  let(:sha) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:base_controller) { Integrations::BaseController.new }

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
      base_controller.expects(:head).with(:ok)
      base_controller.create
      project.releases.count.must_equal 1
      project.builds.count.must_equal 1
    end

    it 'returns :ok if this is not a merge' do
      Integrations::BaseController.any_instance.stubs(:deploy?).returns(false)
      base_controller.expects(:head).with(:ok)
      base_controller.create
      project.releases.count.must_equal 0
      project.builds.count.must_equal 0
    end

    it 're-uses last release if commit already present' do
      stub_github_api("repos/bar/foo/compare/#{sha}...#{sha}", status: 'identical')
      base_controller.expects(:head).with(:ok).twice
      base_controller.create

      base_controller.expects(:latest_release).once
      base_controller.create
      project.releases.count.must_equal 1
      project.builds.count.must_equal 1
    end
  end
end
