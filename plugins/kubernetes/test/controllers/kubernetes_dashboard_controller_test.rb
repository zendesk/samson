require_relative '../test_helper'

describe KubernetesDashboardController do
  as_a_viewer do
    before do
      Kubernetes::Cluster.any_instance.stubs(:client).returns(Kubeclient::Client.new('http://cluster.localhost'))
      stub_request(:get, %r{http://cluster\.localhost.*}).to_return(body: '{}')
    end

    it 'returns an empty array if no pods are running' do
      get :index, project_id: :foo, environment: environments(:production).id, format: :json
      assert_response :success
      response.body.must_equal '[]'
    end

    it 'returns a properly formatted response' do
      # return results only for deploy groups using test_namespace so that additional deploy groups
      # don't break the tests
      stub_request(:get, %r{http://cluster\.localhost.*/namespaces/test_namespace.*}).to_return(body: api_response)
      get :index, project_id: :foo, environment: environments(:production).id, format: :json
      assert_response :success
      compare_json(parse_json_response_file('kubernetes_dashboard_controller_response'), response.body)
    end

    it 'passes correct params to client' do
      Kubeclient::Client.any_instance.expects(:get_pods).once.with(
          { namespace: 'test_namespace', label_selector: 'project=project' }).returns([])
      # expect this call at least once because we might have more deploy groups configured
      Kubeclient::Client.any_instance.expects(:get_pods).at_least_once.with(
          { namespace: 'default', label_selector: 'project=project' }).returns([])
      get :index, project_id: :foo, environment: environments(:production).id, format: :json
      assert_response :success
      response.body.must_equal '[]'
    end
  end

  private

  def api_response
    response = JSON.parse(parse_json_response_file('kubernetes_pod_api_response'))
    response['items'][0]['metadata']['labels']['role_id'] = kubernetes_roles(:app_server).id.to_s
    response['items'][1]['metadata']['labels']['role_id'] = kubernetes_roles(:resque_worker).id.to_s
    response['items'][0]['metadata']['labels']['release_id'] = kubernetes_releases(:test_release).id.to_s
    response['items'][1]['metadata']['labels']['release_id'] = kubernetes_releases(:second_test_release).id.to_s
    JSON.generate(response)
  end

  def compare_json(expected, actual)
    expected_json = JSON.parse(expected)
    actual_json = JSON.parse(actual)
    [expected_json, actual_json].each do |json|
      delete_ids_from json # drop IDs, they're generated
    end
    actual_json.must_equal expected_json
  end

  def delete_ids_from(data)
    if data.is_a? Hash
      data.delete_if { |key, _value| key.end_with? 'id' }
      data.values.each { |value| delete_ids_from value }
    elsif data.is_a? Array
      data.each { |item| delete_ids_from item }
    end
  end
end
