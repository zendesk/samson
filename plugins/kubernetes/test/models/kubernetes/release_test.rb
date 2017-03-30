# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::Release do
  let(:build)  { builds(:docker_build) }
  let(:user)   { users(:deployer) }
  let(:release) do
    Kubernetes::Release.new(build: build, user: user, project: project, git_sha: 'abababa', git_ref: 'master')
  end
  let(:deploy_group) { deploy_groups(:pod1) }
  let(:project) { projects(:test) }
  let(:app_server) { kubernetes_roles(:app_server) }
  let(:resque_worker) { kubernetes_roles(:resque_worker) }
  let(:role_config_file) { read_kubernetes_sample_file('kubernetes_deployment.yml') }

  describe 'validations' do
    it 'is valid by default' do
      assert_valid(release)
    end
  end

  describe "#user" do
    it "is normal user when findable" do
      release.user.class.must_equal User
    end

    it "is NullUser when user was deleted so we can still display the user" do
      release.user_id = 1234
      release.user.class.must_equal NullUser
    end
  end

  describe '#create_release' do
    def assert_create_fails(&block)
      refute_difference 'Kubernetes::Release.count' do
        assert_raises Samson::Hooks::UserError, KeyError, &block
      end
    end

    def assert_create_succeeds(params)
      release = nil
      assert_difference 'Kubernetes::Release.count', +1 do
        release = Kubernetes::Release.create_release(params)
      end
      release
    end

    before { Kubernetes::TemplateFiller.any_instance.stubs(:set_image_pull_secrets) }

    it 'creates with 1 role' do
      expect_file_contents_from_repo
      release = assert_create_succeeds(release_params)
      release.build.id.must_equal release_params[:build_id]
      release.release_docs.count.must_equal 1
      release.release_docs.first.kubernetes_role.id.must_equal app_server.id
      release.release_docs.first.kubernetes_role.name.must_equal app_server.name
    end

    it 'creates with multiple roles' do
      2.times { expect_file_contents_from_repo }
      release = assert_create_succeeds(multiple_roles_release_params)
      release.build.id.must_equal release_params[:build_id]
      release.release_docs.count.must_equal 2
      release.release_docs.first.kubernetes_role.name.must_equal app_server.name
      release.release_docs.first.replica_target.must_equal 1
      release.release_docs.first.cpu.must_equal 1
      release.release_docs.first.ram.must_equal 50
      release.release_docs.second.kubernetes_role.name.must_equal resque_worker.name
      release.release_docs.second.replica_target.must_equal 2
      release.release_docs.second.cpu.must_equal 2
      release.release_docs.second.ram.must_equal 100
    end

    it "fails to save with missing deploy groups" do
      assert_create_fails do
        Kubernetes::Release.create_release(release_params.except(:deploy_groups))
      end
    end

    it "fails to save with empty deploy groups" do
      assert_create_fails do
        Kubernetes::Release.create_release(release_params.tap { |params| params[:deploy_groups].clear })
      end
    end

    it "fails to save with missing roles" do
      assert_create_fails do
        params = release_params.tap { |params| params[:deploy_groups].each { |dg| dg.delete(:roles) } }
        Kubernetes::Release.create_release(params)
      end
    end

    it "fails to save with empty roles" do
      assert_create_fails do
        params = release_params.tap { |params| params[:deploy_groups].each { |dg| dg[:roles].clear } }
        Kubernetes::Release.create_release(params)
      end
    end
  end

  describe "#clients" do
    it "is empty when there are no deploy groups" do
      release.clients.must_equal []
    end

    it "returns scoped queries" do
      release = kubernetes_releases(:test_release)
      stub_request(:get, %r{http://foobar.server/api/v1/namespaces/pod1/pods}).to_return(body: {
        resourceVersion: "1",
        items: [{}, {}]
      }.to_json)
      release.clients.map { |c, q| c.get_pods(q) }.first.size.must_equal 2
    end

    it "can scope queries by resource namespace" do
      release = kubernetes_releases(:test_release)
      Kubernetes::Resource::Deployment.any_instance.stubs(namespace: "default")
      stub_request(:get, %r{http://foobar.server/api/v1/namespaces/default/pods}).to_return(body: {
        resourceVersion: "1",
        items: [{}, {}]
      }.to_json)
      release.clients.map { |c, q| c.get_pods(q) }.first.size.must_equal 2
    end
  end

  describe "#pod_selector" do
    it "generates a query that selects all pods for this deploy group" do
      release.pod_selector(deploy_group).must_equal(
        release_id: release.id,
        deploy_group_id: deploy_group.id
      )
    end
  end

  describe "#validate_project_ids_are_in_sync" do
    it 'ensures project ids are in sync' do
      release.project_id = 123
      refute_valid(release, :build)
    end
  end

  describe '#validate_docker_image_in_registry' do
    it 'ensures image is in registry' do
      release.build = builds(:staging) # does not have a docker image pushed
      refute_valid(release, :build)
    end
  end

  describe "#url" do
    it "builds" do
      release.id = 123
      release.url.must_equal "http://www.test-url.com/projects/foo/kubernetes/releases/123"
    end
  end

  def expect_file_contents_from_repo
    GitRepository.any_instance.expects(:file_content).returns(role_config_file)
  end

  def release_params
    {
      build_id: build.id,
      git_sha: build.git_sha,
      git_ref: build.git_ref,
      project: project,
      deploy_groups: [
        {
          deploy_group: deploy_group,
          roles: [
            {
              role: app_server,
              replicas: 1,
              cpu: 1,
              ram: 50
            }
          ]
        }
      ]
    }
  end

  def multiple_roles_release_params
    release_params.tap do |params|
      params[:deploy_groups].each do |dg|
        dg[:roles].push(role: resque_worker, replicas: 2, cpu: 2, ram: 100)
      end
    end
  end
end
