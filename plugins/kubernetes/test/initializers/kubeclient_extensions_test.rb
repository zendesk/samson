# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered! file: 'plugins/kubernetes/config/initializers/kubeclient_extensions.rb'

describe 'Kubeclient::Client' do
  describe 'entities' do
    let(:entity_list) { %w[Deployment DeploymentRollback DaemonSet Job] }

    it 'defines all the classes' do
      entity_list.each do |entity|
        assert Kernel.const_get "Kubeclient::#{entity}"
      end
    end
  end

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
      stub_request(:post, /rollback/).
        to_return(body: rollback_response_body, status: 200)

      client = Kubeclient::Client.new('http://localhost:8080/api', 'extensions/v1beta1')
      rollback = client.rollback_deployment(deployment_name, 'staging')
      assert_instance_of(Kubeclient::DeploymentRollback, rollback)

      assert_requested(:post,
        "http://localhost:8080/api/extensions/v1beta1/namespaces/staging/deployments/#{deployment_name}/rollback",
        times: 1)
    end
  end
end
