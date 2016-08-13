# frozen_string_literal: true
require_relative '../../../test/test_helper'
require_relative '../lib/samson_kubernetes/hash_kuber_selector'

# Mock up vault client
class VaultClient
  CONFIG_FILE = "vault.json"
  def logical
    @logical ||= Logical.new
  end

  def self.vault_response_object(data)
    Response.new(data)
  end

  def self.client
    @client ||= new
  end

  def initialize
    create_config
    ensure_config_exists
    @expected = {}
    @set = {}
  end

  def list(key)
    @expected.delete("list-#{key}") || raise(KeyError, "list-#{key} not registered")
  end

  def read(key)
    vault_instance(key)
    Response.new(@expected.delete(key) || raise(KeyError, "#{key} not registered"))
  end

  def delete(key)
    @set[key] = nil
    true
  end

  def write(key, body)
    vault_instance(key)
    @set[key] = body
    true
  end

  def config_for(deploy_group_name)
    {
      'vault_address' => 'https://test.hvault.server',
      'tls_verify' => false, "vault_instance": deploy_group_name
    }
  end

  def ensure_config_exists
    raise "config file missing" unless File.exist?(CONFIG_FILE)
  end

  def create_config
    vault_json = {pod2: 'yup', foo: 'bar', group: 'foo', global: 'all your keys are belong to us'}
    File.write(CONFIG_FILE, vault_json.to_json)
  end

  def remove_config
    File.delete(CONFIG_FILE) if File.exist?(CONFIG_FILE)
  end

  def vault_instance(key)
    create_config
    deploy_group = SecretStorage.parse_secret_key(key.split('/', 3).last).fetch(:deploy_group_permalink)
    vaults = JSON.parse(File.read(CONFIG_FILE))
    unless vaults.include?(deploy_group)
      raise(KeyError, "no vault_instance configured for deploy group #{deploy_group}")
    end
  end

  # test hooks
  def clear
    @set.clear
    @expected.clear
  end

  def expect(key, value)
    @expected[key] = value
  end

  attr_reader :set

  def verify!
    @expected.keys.must_equal([], "Expected calls missed: #{@expected.keys}")
  end

  class Response
    attr_accessor :lease_id, :lease_duration, :renewable, :data, :auth
    def initialize(data)
      self.lease_id = nil
      self.lease_duration = nil
      self.renewable = nil
      self.auth = nil
      self.data = data
    end

    def to_h
      instance_values.symbolize_keys
    end
  end
end

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
    Kubernetes::ReleaseDoc.any_instance.stubs(raw_template: read_kubernetes_sample_file('kubernetes_deployment.yml'))
  end

  def kubernetes_sample_file_path(file_name)
    "#{Rails.root}/plugins/kubernetes/test/samples/#{file_name}"
  end

  def read_kubernetes_sample_file(file_name)
    File.read(kubernetes_sample_file_path(file_name))
  end
end
