# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::BlueGreenDeployExecutor do
  def add_service_to_release_doc
    kubernetes_fake_raw_template
    Kubernetes::TemplateFiller.any_instance.stubs(:set_image_pull_secrets)
    doc = release.release_docs.first
    doc.send(:store_resource_template)
    doc.save!(validate: false)
  end

  def create_previous_successful_release
    other = Kubernetes::Release.new(
      user: release.user,
      project: release.project,
      git_sha: release.git_sha,
      git_ref: "master",
      deploy: release.deploy,
      blue_phase: false
    )
    other.release_docs = release.release_docs.map do |doc|
      copy = Kubernetes::ReleaseDoc.new(doc.attributes.except('resource_template'))
      copy.send(:resource_template=, doc.resource_template.map do |t|
        t.deep_merge(metadata: {name: t.dig(:metadata, :name).sub("-blue", "-green")})
      end)
      copy.kubernetes_release = other
      copy
    end
    Kubernetes::Release.any_instance.stubs(:previous_successful_release).returns(other)
  end

  let(:output) { StringIO.new }
  let(:out) { output.string }
  let(:stage) { deploy.stage }
  let(:deploy) { job.deploy }
  let(:job) { jobs(:succeeded_test) }
  let(:project) { job.project }
  let(:build) { builds(:docker_build) }
  let(:deploy_group) { stage.deploy_groups.first }
  let(:release) { kubernetes_releases(:test_release) }
  let(:executor) { Kubernetes::BlueGreenDeployExecutor.new(output, job: job, reference: 'master') }
  let(:commit) { '1a6f551a2ffa6d88e15eef5461384da0bfb1c194' }
  let(:deployments_url) { "#{origin}/apis/extensions/v1beta1/namespaces/pod1/deployments" }
  let(:services_url) { "#{origin}/api/v1/namespaces/pod1/services" }
  let(:origin) { "http://foobar.server" }

  assert_requests

  before do
    stage.update_columns kubernetes: true, blue_green: true
    deploy.update_columns kubernetes: true
    release.update_columns blue_phase: true
    add_service_to_release_doc
  end

  describe "#deploy_and_watch" do
    it "deploys new resources" do
      # deployment
      assert_request(:get, "#{deployments_url}/test-app-server-blue", to_return: {status: 404}) # blue did not exist
      assert_request(:post, deployments_url, to_return: {body: "{}"}) # blue was created

      # service
      assert_request(:get, "#{services_url}/some-project", to_return: {status: 404}) # did not exist
      assert_request(:post, services_url, to_return: {body: "{}"}) # blue was created

      executor.expects(:wait_for_resources_to_complete).returns(true)
      assert executor.send(:deploy_and_watch, release, release.release_docs)

      out.must_equal <<~OUT
        Creating BLUE resources for Pod1 role app-server
        Switching service for Pod1 role app-server to BLUE
        SUCCESS
      OUT
    end

    it "updates existing resources" do
      create_previous_successful_release

      # deployment
      assert_request(:get, "#{deployments_url}/test-app-server-blue", to_return: {status: 404}) # blue did not exist
      assert_request(:post, deployments_url, to_return: {body: "{}"}) # blue was created

      # service
      assert_request(:get, "#{services_url}/some-project", to_return: {body: "{}"}) # existed
      assert_request(:put, "#{services_url}/some-project", to_return: {body: "{}"}) # update to point to blue

      # delete old deployment
      assert_request(
        :get, "#{deployments_url}/test-app-server-green",
        to_return: [{body: "{}"}, {body: "{}"}, {status: 404}] # green did exist and gets deleted
      )
      assert_request(:put, "#{deployments_url}/test-app-server-green", to_return: {body: "{}"}) # set green to 0
      assert_request(:delete, "#{deployments_url}/test-app-server-green", to_return: {body: "{}"}) # delete green

      executor.expects(:wait_for_resources_to_complete).returns(true)
      assert executor.send(:deploy_and_watch, release, release.release_docs)

      out.must_equal <<~OUT
        Creating BLUE resources for Pod1 role app-server
        Switching service for Pod1 role app-server to BLUE
        Deleting GREEN resources for Pod1 role app-server
        SUCCESS
      OUT
    end

    it "reverts new resources when they fail" do
      # deployment
      assert_request(
        :get, "#{deployments_url}/test-app-server-blue", to_return:
        [
          {status: 404}, {body: "{}"}, {body: "{}"}, {status: 404} # blue did not exist + 3 replies for deletion
        ]
      )
      assert_request(:post, deployments_url, to_return: {body: "{}"}) # blue was created
      assert_request(:put, "#{deployments_url}/test-app-server-blue", to_return: {body: "{}"}) # set blue to 0
      assert_request(:delete, "#{deployments_url}/test-app-server-blue", to_return: {body: "{}"}) # delete blue

      executor.expects(:wait_for_resources_to_complete).returns([])
      executor.expects(:print_resource_events)
      refute executor.send(:deploy_and_watch, release, release.release_docs)

      out.must_equal <<~OUT
        Creating BLUE resources for Pod1 role app-server
        Deleting BLUE resources for Pod1 role app-server
        DONE
      OUT
    end
  end
end
