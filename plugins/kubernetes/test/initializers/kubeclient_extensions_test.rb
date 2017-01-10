# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered! file: 'plugins/kubernetes/config/initializers/kubeclient_extensions.rb'

describe Kubeclient::Client do
  describe '#rollback_deployment' do
    let(:deployment_name) { 'test-deploy' }
    let(:rollback_response_body) do
      {
        kind: 'DeploymentRollback',
        apiVersion: 'extensions/v1beta',
        name: deployment_name,
        rollbackTo: {
          revision: 0
        }
      }.to_json
    end

    it 'works' do
      request = stub_request(
        :post,
        "http://foobar.server/apis/extensions/v1beta1/namespaces/staging/deployments/#{deployment_name}/rollback"
      ).to_return(body: rollback_response_body, status: 200)

      client = Kubeclient::Client.new('http://foobar.server/apis', 'extensions/v1beta1')
      rollback = client.rollback_deployment(deployment_name, 'staging')
      assert_instance_of(Kubeclient::Client::DeploymentRollback, rollback)

      assert_requested(request, times: 1)
    end
  end
end

describe KubeException do
  it "has request information" do
    client = Kubeclient::Client.new('http://foobar.server/apis')
    stub_request(:get, "http://foobar.server/apis/v1").to_return(status: 404)
    e = assert_raises(KubeException) { client.get_secret 'nope' }
    e.to_s.must_equal "HTTP status code 404 404 Not Found for GET http://foobar.server/apis/v1"
  end
end
