require 'test_helper'

# Pod entity tests
class TestPod < MiniTest::Test
  def test_get_from_json_v1
    stub_request(:get, %r{/pods})
      .to_return(body: open_test_file('pod.json'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'
    pod = client.get_pod 'redis-master-pod', 'default'

    assert_instance_of(Kubeclient::Pod, pod)
    assert_equal('redis-master3', pod.metadata.name)
    assert_equal('dockerfile/redis', pod.spec.containers[0]['image'])

    assert_requested(:get,
                     'http://localhost:8080/api/v1/namespaces/default/pods/redis-master-pod',
                     times: 1)
  end
end
