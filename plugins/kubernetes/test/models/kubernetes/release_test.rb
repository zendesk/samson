# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::Release do
  let(:build)  { builds(:docker_build) }
  let(:user)   { users(:deployer) }
  let(:release) do
    Kubernetes::Release.new(
      user: user,
      project: project,
      git_sha: build.git_sha,
      git_ref: 'master',
      deploy: deploys(:succeeded_test)
    )
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

  describe '#build_release_docs' do
    before do
      Kubernetes::TemplateFiller.any_instance.stubs(:set_image_pull_secrets)
    end

    it 'creates with 1 role' do
      expect_file_contents_from_repo
      release = Kubernetes::Release.build_release_with_docs(release_params)
      release.must_be :valid?
      release.release_docs.size.must_equal 1
      release.release_docs.first.kubernetes_role.id.must_equal app_server.id
      release.release_docs.first.kubernetes_role.name.must_equal app_server.name

      assert_difference -> { Kubernetes::Release.count } => +1, -> { Kubernetes::ReleaseDoc.count } => +1 do
        release.save
      end
    end

    it 'creates with multiple roles' do
      2.times { expect_file_contents_from_repo }
      release = Kubernetes::Release.build_release_with_docs(multiple_roles_release_params)
      release.must_be :valid?
      release.release_docs.size.must_equal 2
      release.release_docs.first.kubernetes_role.name.must_equal app_server.name
      release.release_docs.first.replica_target.must_equal 1
      release.release_docs.second.kubernetes_role.name.must_equal resque_worker.name
      release.release_docs.second.replica_target.must_equal 2

      assert_difference -> { Kubernetes::Release.count } => +1, -> { Kubernetes::ReleaseDoc.count } => +2 do
        release.save
      end
    end

    it "fails to save with missing deploy groups" do
      release_params.delete :grouped_deploy_group_roles
      assert_raises Samson::Hooks::UserError do
        Kubernetes::Release.build_release_with_docs(release_params)
      end
    end

    it "fails to save with empty deploy groups" do
      release_params[:grouped_deploy_group_roles].first.clear
      assert_raises Samson::Hooks::UserError do
        Kubernetes::Release.build_release_with_docs(release_params)
      end
    end

    it "fails to populate release docs when invalid" do
      Kubernetes::Release.any_instance.expects(:valid?).returns(false)
      Kubernetes::Release.build_release_with_docs(release_params).release_docs.must_be :empty?
    end

    it "adds created_cluster_resources" do
      role_config_file << <<~YAML
        ---
        apiVersion: templates.gatekeeper.sh/v1
        kind: ConstraintTemplate
        metadata:
          name: foo
          labels:
            project: some-project
            role: some-role
        spec:
          crd:
            spec:
              names:
                kind: Foobar
      YAML
      expect_file_contents_from_repo
      release = Kubernetes::Release.build_release_with_docs(release_params)
      assert_valid release.release_docs.first
      assert_valid release
      release.release_docs.first.created_cluster_resources.must_equal(
        "Foobar" => {"namespaced" => false}
      )
    end

    describe "blue green" do
      before do
        expect_file_contents_from_repo
        app_server.blue_green = true
      end

      it 'defaults to blue when not using blue_green' do
        app_server.blue_green = false
        subject = Kubernetes::Release.build_release_with_docs(release_params)
        subject.blue_green_color.must_equal "blue"
      end

      it 'creates first as blue' do
        subject = Kubernetes::Release.build_release_with_docs(release_params)
        subject.blue_green_color.must_equal "blue"
      end

      it 'creates followup as green' do
        release.blue_green_color = "blue"
        Kubernetes::Release.any_instance.expects(:previous_succeeded_release).returns(release)
        subject = Kubernetes::Release.build_release_with_docs(release_params)
        subject.blue_green_color.must_equal "green"
      end
    end
  end

  describe "#clients" do
    it "is empty when there are no deploy groups" do
      release.clients("v1").must_equal []
    end

    it "returns scoped queries" do
      release = kubernetes_releases(:test_release)
      stub_request(:get, %r{namespaces/pod1/pods\?labelSelector=release_id=\d+,deploy_group_id=\d+}).
        to_return(
          body: {
            resourceVersion: "1",
            items: [{}, {}]
          }.to_json
        )
      release.clients("v1").map { |c, q| c.get_pods(q).fetch(:items) }.first.size.must_equal 2
    end

    it "can scope queries by resource namespace" do
      release = kubernetes_releases(:test_release)
      Kubernetes::Resource::Base.any_instance.stubs(namespace: "default")
      stub_request(:get, %r{http://foobar.server/api/v1/namespaces/default/pods}).
        to_return(
          body: {
            resourceVersion: "1",
            items: [{}, {}]
          }.to_json
        )
      release.clients("v1").map { |c, q| c.get_pods(q).fetch(:items) }.first.size.must_equal 2
    end
  end

  describe ".pod_selector" do
    it "generates a query that selects all pods for this deploy group" do
      Kubernetes::Release.pod_selector(123, deploy_group.id, query: true).must_equal(
        "release_id=123,deploy_group_id=#{deploy_group.id}"
      )
    end

    it "generates raw labels" do
      Kubernetes::Release.pod_selector(123, deploy_group.id, query: false).must_equal(
        release_id: 123,
        deploy_group_id: deploy_group.id
      )
    end
  end

  describe "#previous_succeeded_release" do
    before { release.deploy = deploys(:failed_staging_test) }

    it "finds succeeded release" do
      release.previous_succeeded_release.must_equal kubernetes_releases(:test_release)
    end

    it "is nil when non was found" do
      deploys(:succeeded_test).delete
      release.previous_succeeded_release.must_be_nil
    end

    it "is ignores failed releases" do
      deploys(:succeeded_test).job.update_column(:status, 'failed')
      release.previous_succeeded_release.must_be_nil
    end
  end

  def expect_file_contents_from_repo
    GitRepository.any_instance.expects(:file_content).returns(role_config_file)
  end

  def release_params
    @release_params ||= {
      builds: [build],
      git_sha: build.git_sha,
      git_ref: build.git_ref,
      project: project,
      user: user,
      deploy: deploys(:succeeded_test),
      grouped_deploy_group_roles: [
        [
          Kubernetes::DeployGroupRole.new(
            deploy_group: deploy_group,
            kubernetes_role: app_server,
            replicas: 1,
            requests_cpu: 0.5,
            requests_memory: 20,
            limits_cpu: 1,
            limits_memory: 50,
            delete_resource: false
          )
        ]
      ]
    }
  end

  def multiple_roles_release_params
    release_params.tap do |params|
      params[:grouped_deploy_group_roles].each do |dgrs|
        copy = dgrs.first.dup
        copy.attributes = {
          kubernetes_role: resque_worker,
          replicas: 2,
          limits_cpu: 2,
          limits_memory: 100,
          requests_cpu: 1,
          requests_memory: 50,
          delete_resource: false
        }
        dgrs.push(copy)
      end
    end
  end
end
