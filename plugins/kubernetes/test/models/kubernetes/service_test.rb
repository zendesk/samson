# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Service do
  let(:template) do
    # simulate what ReleaseDoc does
    config = YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml'))[1]
    config['metadata']['namespace'] = deploy_group.kubernetes_namespace
    config.deep_symbolize_keys
  end
  let(:deploy_group) { deploy_groups(:pod1) }
  let(:service) { Kubernetes::Service.new(template, deploy_group) }

  describe "#name" do
    it "returns the name" do
      service.name.must_equal 'some-project'
    end
  end

  describe "#namespace" do
    it "returns the namespace" do
      service.namespace.must_equal 'pod1'
    end
  end

  describe "#create" do
    let!(:request) { stub_request(:post, "http://foobar.server/api/v1/namespaces/pod1/services").to_return(body: "{}") }

    it "creates" do
      service.create
      assert_requested request
    end

    it "does not fetch when using the object after creating" do
      service.create
      service.running?
    end
  end

  describe "#running?" do
    let(:url) { "http://foobar.server/api/v1/namespaces/pod1/services/some-project" }

    it "is true when running" do
      stub_request(:get, url).to_return(body: "{}")
      assert service.running?
    end

    it "is false when not running" do
      stub_request(:get, url).to_return(status: 404)
      refute service.running?
    end

    it "raises when a non 404 exception is raised" do
      stub_request(:get, url).to_return(status: 500)
      assert_raises(KubeException) { service.running? }
    end
  end
end
