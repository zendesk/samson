require 'test_helper'

# Pod log tests
class TestPodLog < MiniTest::Test
  def test_get_pod_log
    stub_request(:get, %r{/namespaces/default/pods/[a-z0-9-]+/log})
      .to_return(body: open_test_file('pod_log.txt'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'
    retrieved_log = client.get_pod_log('redis-master-pod', 'default')

    assert_equal(open_test_file('pod_log.txt').read, retrieved_log)

    assert_requested(:get,
                     'http://localhost:8080/api/v1/namespaces/default/pods/redis-master-pod/log',
                     times: 1)
  end

  def test_get_pod_log_container
    stub_request(:get, %r{/namespaces/default/pods/[a-z0-9-]+/log})
      .to_return(body: open_test_file('pod_log.txt'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'
    retrieved_log = client.get_pod_log('redis-master-pod', 'default', container: 'ruby')

    assert_equal(open_test_file('pod_log.txt').read, retrieved_log)

    assert_requested(:get,
                     'http://localhost:8080/api/v1/namespaces/default/pods/redis-master-pod/log?container=ruby',
                     times: 1)
  end

  def test_watch_pod_log
    expected_lines = open_test_file('pod_log.txt').read.split("\n")

    stub_request(:get, %r{/namespaces/default/pods/[a-z0-9-]+/log\?.*follow})
      .to_return(body: open_test_file('pod_log.txt'),
                 status: 200)

    client = Kubeclient::Client.new 'http://localhost:8080/api/', 'v1'

    stream = client.watch_pod_log('redis-master-pod', 'default')
    stream.to_enum.with_index do |notice, index|
      assert_instance_of(String, notice)
      assert_equal(expected_lines[index], notice)
    end
  end
end
