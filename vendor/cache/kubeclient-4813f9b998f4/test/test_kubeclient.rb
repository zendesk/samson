require 'test_helper'

# Kubernetes client entity tests
class KubeClientTest < MiniTest::Test
  def test_json
    our_object = Kubeclient::Service.new
    our_object.foo = 'bar'
    our_object.nested = {}
    our_object.nested.again = {}
    our_object.nested.again.again = {}
    our_object.nested.again.again.name = 'aaron'

    expected = { 'foo' => 'bar', 'nested' => { 'again' => { 'again' =>
                 { 'name' => 'aaron' } } } }

    assert_equal(expected, JSON.parse(JSON.dump(our_object.to_h)))
  end

  def test_pass_uri
    # URI::Generic#hostname= was added in ruby 1.9.3 and will automatically
    # wrap an ipv6 address in []
    uri = URI::HTTP.build(port: 8080)
    uri.hostname = 'localhost'
    client = Kubeclient::Client.new uri
    rest_client = client.rest_client
    assert_equal 'http://localhost:8080/api/v1', rest_client.url.to_s
  end

  def test_no_path_in_uri
    client = Kubeclient::Client.new 'http://localhost:8080', 'v1'
    rest_client = client.rest_client
    assert_equal 'http://localhost:8080/api/v1', rest_client.url.to_s
  end

  def test_no_version_passed
    client = Kubeclient::Client.new 'http://localhost:8080'
    rest_client = client.rest_client
    assert_equal 'http://localhost:8080/api/v1', rest_client.url.to_s
  end

  def test_exception
    stub_request(:post, %r{/services})
      .to_return(body: open_test_file('namespace_exception.json'),
                 status: 409)

    service = Kubeclient::Service.new
    service.metadata = {}
    service.metadata.name = 'redisslave'
    service.metadata.namespace = 'default'
    # service.port = 80
    # service.container_port = 6379
    # service.protocol = 'TCP'

    client = Kubeclient::Client.new 'http://localhost:8080/api/'

    exception = assert_raises(KubeException) do
      service = client.create_service service
    end

    assert_instance_of(KubeException, exception)
    assert_equal("converting  to : type names don't match (Pod, Namespace)",
                 exception.message)
    assert_equal(409, exception.error_code)
  end

  def test_api
    stub_request(:get, 'http://localhost:8080/api')
      .to_return(status: 200, body: open_test_file('versions_list.json'))

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'
    response = client.api
    assert_includes(response, 'versions')
  end

  def test_api_ssl_failure
    error_message = 'certificate verify failed'

    stub_request(:get, 'http://localhost:8080/api')
      .to_raise(OpenSSL::SSL::SSLError.new(error_message))

    client = Kubeclient::Client.new 'http://localhost:8080/api/'

    exception = assert_raises(KubeException) { client.api }
    assert_equal(error_message, exception.message)
  end

  def test_api_valid
    stub_request(:get, 'http://localhost:8080/api')
      .to_return(status: 200, body: open_test_file('versions_list.json'))

    args = ['http://localhost:8080/api/']

    [nil, 'v1beta3', 'v1'].each do |version|
      client = Kubeclient::Client.new(*(version ? args + [version] : args))
      assert client.api_valid?
    end
  end

  def test_api_valid_with_invalid_version
    stub_request(:get, 'http://localhost:8080/api')
      .to_return(status: 200, body: open_test_file('versions_list.json'))

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'foobar1'
    refute client.api_valid?
  end

  def test_api_valid_with_unreported_versions
    stub_request(:get, 'http://localhost:8080/api')
      .to_return(status: 200, body: '{}')

    client = Kubeclient::Client.new 'http://localhost:8080/api/'
    refute client.api_valid?
  end

  def test_api_valid_with_invalid_json
    stub_request(:get, 'http://localhost:8080/api')
      .to_return(status: 200, body: '[]')

    client = Kubeclient::Client.new 'http://localhost:8080/api/'
    refute client.api_valid?
  end

  def test_api_valid_with_bad_endpoint
    stub_request(:get, 'http://localhost:8080/api')
      .to_return(status: [404, 'Resource Not Found'])

    client = Kubeclient::Client.new 'http://localhost:8080/api/'
    assert_raises(KubeException) { client.api_valid? }
  end

  def test_api_valid_with_non_json
    stub_request(:get, 'http://localhost:8080/api')
      .to_return(status: 200, body: '<html></html>')

    client = Kubeclient::Client.new 'http://localhost:8080/api/'
    assert_raises(JSON::ParserError) { client.api_valid? }
  end

  def test_nonjson_exception
    stub_request(:get, %r{/servic})
      .to_return(body: open_test_file('service_illegal_json_404.json'),
                 status: 404)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'

    exception = assert_raises(KubeException) do
      client.get_services
    end

    assert_instance_of(KubeException, exception)
    assert(exception.message.include?('Not Found'))
    assert_equal(404, exception.error_code)
  end

  def test_entity_list
    stub_request(:get, %r{/services})
      .to_return(body: open_test_file('entity_list.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'
    services = client.get_services

    refute_empty(services)
    assert_instance_of(Kubeclient::Common::EntityList, services)
    assert_equal('Service', services.kind)
    assert_equal(2, services.size)
    assert_instance_of(Kubeclient::Service, services[0])
    assert_instance_of(Kubeclient::Service, services[1])

    assert_requested(:get,
                     'http://localhost:8080/api/v1/services',
                     times: 1)
  end

  def test_entities_with_label_selector
    selector = 'component=apiserver'

    stub_request(:get, %r{/services})
      .to_return(body: open_test_file('entity_list.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'
    services = client.get_services(label_selector: selector)

    assert_instance_of(Kubeclient::Common::EntityList, services)
    assert_requested(:get,
                     "http://localhost:8080/api/v1/services?labelSelector=#{selector}",
                     times: 1)
  end

  def test_entities_with_field_selector
    selector = 'involvedObject.name=redis-master'

    stub_request(:get, %r{/services})
      .to_return(body: open_test_file('entity_list.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'
    services = client.get_services(field_selector: selector)

    assert_instance_of(Kubeclient::Common::EntityList, services)
    assert_requested(:get,
                     "http://localhost:8080/api/v1/services?fieldSelector=#{selector}",
                     times: 1)
  end

  def test_empty_list
    stub_request(:get, %r{/pods})
      .to_return(body: open_test_file('empty_pod_list.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'
    pods = client.get_pods
    assert_instance_of(Kubeclient::Common::EntityList, pods)
    assert_equal(0, pods.size)
  end

  def test_get_all
    stub_request(:get, %r{/services})
      .to_return(body: open_test_file('service_list.json'),
                 status: 200)

    stub_request(:get, %r{/pods})
      .to_return(body: open_test_file('pod_list.json'),
                 status: 200)

    stub_request(:get, %r{/nodes})
      .to_return(body: open_test_file('node_list.json'),
                 status: 200)

    stub_request(:get, %r{/replicationcontrollers})
      .to_return(body: open_test_file('replication_controller_list.json'), status: 200)

    stub_request(:get, %r{/events})
      .to_return(body: open_test_file('event_list.json'), status: 200)

    stub_request(:get, %r{/endpoints})
      .to_return(body: open_test_file('endpoint_list.json'),
                 status: 200)

    stub_request(:get, %r{/namespaces})
      .to_return(body: open_test_file('namespace_list.json'),
                 status: 200)

    stub_request(:get, %r{/secrets})
      .to_return(body: open_test_file('secret_list.json'),
                 status: 200)

    stub_request(:get, %r{/resourcequotas})
      .to_return(body: open_test_file('resource_quota_list.json'),
                 status: 200)

    stub_request(:get, %r{/limitranges})
      .to_return(body: open_test_file('limit_range_list.json'),
                 status: 200)

    stub_request(:get, %r{/persistentvolumes})
      .to_return(body: open_test_file('persistent_volume_list.json'),
                 status: 200)

    stub_request(:get, %r{/persistentvolumeclaims})
      .to_return(body: open_test_file('persistent_volume_claim_list.json'),
                 status: 200)

    stub_request(:get, %r{/componentstatuses})
      .to_return(body: open_test_file('component_status_list.json'),
                 status: 200)

    stub_request(:get, %r{/serviceaccounts})
      .to_return(body: open_test_file('service_account_list.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'
    result = client.all_entities
    assert_equal(14, result.keys.size)
    assert_instance_of(Kubeclient::Common::EntityList, result['node'])
    assert_instance_of(Kubeclient::Common::EntityList, result['service'])
    assert_instance_of(Kubeclient::Common::EntityList,
                       result['replication_controller'])
    assert_instance_of(Kubeclient::Common::EntityList, result['pod'])
    assert_instance_of(Kubeclient::Common::EntityList, result['event'])
    assert_instance_of(Kubeclient::Common::EntityList, result['namespace'])
    assert_instance_of(Kubeclient::Common::EntityList, result['secret'])
    assert_instance_of(Kubeclient::Service, result['service'][0])
    assert_instance_of(Kubeclient::Node, result['node'][0])
    assert_instance_of(Kubeclient::Event, result['event'][0])
    assert_instance_of(Kubeclient::Endpoint, result['endpoint'][0])
    assert_instance_of(Kubeclient::Namespace, result['namespace'][0])
    assert_instance_of(Kubeclient::Secret, result['secret'][0])
    assert_instance_of(Kubeclient::ResourceQuota, result['resource_quota'][0])
    assert_instance_of(Kubeclient::LimitRange, result['limit_range'][0])
    assert_instance_of(Kubeclient::PersistentVolume, result['persistent_volume'][0])
    assert_instance_of(Kubeclient::PersistentVolumeClaim, result['persistent_volume_claim'][0])
    assert_instance_of(Kubeclient::ComponentStatus, result['component_status'][0])
    assert_instance_of(Kubeclient::ServiceAccount, result['service_account'][0])
  end

  def test_api_bearer_token_with_params_success
    stub_request(:get, 'http://localhost:8080/api/v1/pods?labelSelector=name=redis-master')
      .with(headers: { Authorization: 'Bearer valid_token' })
      .to_return(body: open_test_file('pod_list.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/',
                                    auth_options: {
                                      bearer_token: 'valid_token'
                                    }

    pods = client.get_pods(label_selector: 'name=redis-master')

    assert_equal('Pod', pods.kind)
    assert_equal(1, pods.size)
  end

  def test_api_bearer_token_success
    stub_request(:get, 'http://localhost:8080/api/v1/pods')
      .with(headers: { Authorization: 'Bearer valid_token' })
      .to_return(body: open_test_file('pod_list.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/',
                                    auth_options: {
                                      bearer_token: 'valid_token'
                                    }

    pods = client.get_pods

    assert_equal('Pod', pods.kind)
    assert_equal(1, pods.size)
  end

  def test_api_bearer_token_failure
    error_message = '"/api/v1/pods" is forbidden because ' \
                    'system:anonymous cannot list on pods in'
    response = OpenStruct.new(code: 401, message: error_message)

    stub_request(:get, 'http://localhost:8080/api/v1/pods')
      .with(headers: { Authorization: 'Bearer invalid_token' })
      .to_raise(KubeException.new(403, error_message, response))

    client = Kubeclient::Client.new 'http://localhost:8080/api/',
                                    auth_options: {
                                      bearer_token: 'invalid_token'
                                    }

    exception = assert_raises(KubeException) { client.get_pods }
    assert_equal(403, exception.error_code)
    assert_equal(error_message, exception.message)
    assert_equal(response, exception.response)
  end

  def test_api_basic_auth_success
    stub_request(:get, 'http://username:password@localhost:8080/api/v1/pods')
      .to_return(body: open_test_file('pod_list.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/',
                                    auth_options: {
                                      username: 'username',
                                      password: 'password'
                                    }

    pods = client.get_pods

    assert_equal('Pod', pods.kind)
    assert_equal(1, pods.size)
    assert_requested(:get,
                     'http://username:password@localhost:8080/api/v1/pods',
                     times: 1)
  end

  def test_api_basic_auth_back_comp_success
    stub_request(:get, 'http://username:password@localhost:8080/api/v1/pods')
      .to_return(body: open_test_file('pod_list.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/',
                                    auth_options: {
                                      user: 'username',
                                      password: 'password'
                                    }

    pods = client.get_pods

    assert_equal('Pod', pods.kind)
    assert_equal(1, pods.size)
    assert_requested(:get,
                     'http://username:password@localhost:8080/api/v1/pods',
                     times: 1)
  end

  def test_api_basic_auth_failure
    error_message = 'HTTP status code 401, 401 Unauthorized'
    response = OpenStruct.new(code: 401, message: '401 Unauthorized')

    stub_request(:get, 'http://username:password@localhost:8080/api/v1/pods')
      .to_raise(KubeException.new(401, error_message, response))

    client = Kubeclient::Client.new 'http://localhost:8080/api/',
                                    auth_options: {
                                      username: 'username',
                                      password: 'password'
                                    }

    exception = assert_raises(KubeException) { client.get_pods }
    assert_equal(401, exception.error_code)
    assert_equal(error_message, exception.message)
    assert_equal(response, exception.response)
    assert_requested(:get,
                     'http://username:password@localhost:8080/api/v1/pods',
                     times: 1)
  end

  def test_init_username_no_password
    expected_msg = 'Basic auth requires both username & password'
    exception = assert_raises(ArgumentError) do
      Kubeclient::Client.new 'http://localhost:8080',
                             auth_options: {
                               username: 'username'
                             }
    end
    assert_equal expected_msg, exception.message
  end

  def test_init_user_no_password
    expected_msg = 'Basic auth requires both username & password'
    exception = assert_raises(ArgumentError) do
      Kubeclient::Client.new 'http://localhost:8080',
                             auth_options: {
                               user: 'username'
                             }
    end
    assert_equal expected_msg, exception.message
  end

  def test_init_username_and_bearer_token
    expected_msg = 'Invalid auth options: specify only one of username/password,' \
                   ' bearer_token or bearer_token_file'
    exception = assert_raises(ArgumentError) do
      Kubeclient::Client.new 'http://localhost:8080',
                             auth_options: {
                               username: 'username',
                               bearer_token: 'token'
                             }
    end
    assert_equal expected_msg, exception.message
  end

  def test_init_user_and_bearer_token
    expected_msg = 'Invalid auth options: specify only one of username/password,' \
                   ' bearer_token or bearer_token_file'
    exception = assert_raises(ArgumentError) do
      Kubeclient::Client.new 'http://localhost:8080',
                             auth_options: {
                               username: 'username',
                               bearer_token: 'token'
                             }
    end
    assert_equal expected_msg, exception.message
  end

  def test_bearer_token_and_bearer_token_file
    expected_msg = 'Invalid auth options: specify only one of username/password,' \
                   ' bearer_token or bearer_token_file'
    exception = assert_raises(ArgumentError) do
      Kubeclient::Client.new 'http://localhost:8080',
                             auth_options: {
                               bearer_token: 'token',
                               bearer_token_file: 'token-file'
                             }
    end
    assert_equal expected_msg, exception.message
  end

  def test_bearer_token_file_not_exist
    expected_msg = 'Token file token-file does not exist'
    exception = assert_raises(ArgumentError) do
      Kubeclient::Client.new 'http://localhost:8080',
                             auth_options: {
                               bearer_token_file: 'token-file'
                             }
    end
    assert_equal expected_msg, exception.message
  end

  def test_api_bearer_token_file_success
    stub_request(:get, 'http://localhost:8080/api/v1/pods')
      .with(headers: { Authorization: 'Bearer valid_token' })
      .to_return(body: open_test_file('pod_list.json'),
                 status: 200)

    file = File.join(File.dirname(__FILE__), 'valid_token_file')
    client = Kubeclient::Client.new 'http://localhost:8080/api/',
                                    auth_options: {
                                      bearer_token_file: file
                                    }

    pods = client.get_pods

    assert_equal('Pod', pods.kind)
    assert_equal(1, pods.size)
  end

  def test_proxy_url
    client = Kubeclient::Client.new 'http://host:8080', 'v1'
    assert_equal('http://host:8080/api/v1/proxy/namespaces/ns/services/srvname:srvportname',
                 client.proxy_url('service', 'srvname', 'srvportname', 'ns'))

    assert_equal('http://host:8080/api/v1/namespaces/ns/pods/srvname:srvportname/proxy',
                 client.proxy_url('pods', 'srvname', 'srvportname', 'ns'))

    # Check no namespace provided
    assert_equal('http://host:8080/api/v1/proxy/nodes/srvname:srvportname',
                 client.proxy_url('nodes', 'srvname', 'srvportname'))

    # Check integer port
    assert_equal('http://host:8080/api/v1/proxy/nodes/srvname:5001',
                 client.proxy_url('nodes', 'srvname', 5001))
  end

  def test_attr_readers
    client = Kubeclient::Client.new 'http://localhost:8080/api/',
                                    ssl_options: {
                                      client_key: 'secret'
                                    },
                                    auth_options: {
                                      bearer_token: 'token'
                                    }
    assert_equal '/api', client.api_endpoint.path
    assert_equal 'secret', client.ssl_options[:client_key]
    assert_equal 'token', client.auth_options[:bearer_token]
    assert_equal 'Bearer token', client.headers[:Authorization]
  end

  def test_nil_items
    # handle https://github.com/kubernetes/kubernetes/issues/13096
    stub_request(:get, %r{/persistentvolumeclaims})
      .to_return(body: open_test_file('persistent_volume_claims_nil_items.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'
    client.get_persistent_volume_claims
  end

  private

  # dup method creates a shallow copy which is not good in this case
  # since rename_keys changes the input hash
  # hence need to create a deep_copy
  def deep_copy(hash)
    Marshal.load(Marshal.dump(hash))
  end
end
