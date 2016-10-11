# frozen_string_literal: true
require_relative '../../../test/test_helper'

class ActiveSupport::TestCase
  def with_example_kube_config
    Tempfile.open('config') do |t|
      config = {
        'apiVersion' => 'v1',
        'users' => nil,
        'clusters' => [
          {
            'name' => 'somecluster',
            'cluster' => { 'server' => 'http://k8s.example.com' }
          }
        ],
        'contexts' => [
          {
            'name' => 'default',
            'context' => { 'cluster' => 'somecluster', 'user' => '' }
          }
        ],
        'current-context' => 'default'
      }
      t.write(config.to_yaml)
      t.flush
      yield t.path
    end
  end

  def create_kubernetes_cluster(attr = {})
    Kubernetes::Cluster.any_instance.stubs(connection_valid?: true)
    cluster_attr = {
      name: 'Foo',
      config_filepath: File.join(File.dirname(__FILE__), 'cluster_config.yml'),
      config_context: 'test'
    }.merge(attr)
    Kubernetes::Cluster.create!(cluster_attr)
  end

  def kubernetes_fake_raw_template
    role = Kubernetes::RoleConfigFile.new(
      read_kubernetes_sample_file('kubernetes_deployment.yml'),
      'config/app_server.yml'
    )
    Kubernetes::ReleaseDoc.any_instance.stubs(raw_template: role.elements)
  end

  def kubernetes_sample_file_path(file_name)
    "#{Rails.root}/plugins/kubernetes/test/samples/#{file_name}"
  end

  def read_kubernetes_sample_file(file_name)
    File.read(kubernetes_sample_file_path(file_name))
  end
end
