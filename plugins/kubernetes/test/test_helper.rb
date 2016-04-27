require_relative '../../../test/test_helper'
require_relative '../lib/samson_kubernetes/hash_kuber_selector'
require 'celluloid/test'

class ActiveSupport::TestCase
  def self.it_responds_with_unauthorized(&block)
    it 'responds with unauthorized' do
      self.instance_eval(&block)
      @unauthorized.must_equal true, 'Request should get unauthorized'
    end
  end

  def self.it_responds_successfully(&block)
    it 'responds successfully' do
      self.instance_eval(&block)
      assert_response :success
    end
  end

  def self.it_responds_with_bad_request(&block)
    it 'responds with 400 Bad Request' do
      self.instance_eval(&block)
      assert_response :bad_request
    end
  end

  def self.it_should_raise_an_exception(&block)
    it 'should raise an exception' do
      assert_raises Exception do
        self.instance_eval(&block)
      end
    end
  end

  def parse_role_config_file(file_name)
    read_file "#{file_name}.yml"
  end

  def parse_json_response_file(file_name)
    read_file "#{file_name}.json"
  end

  def with_example_kube_config
    Tempfile.open('config') do |t|
      t.write({'users': [], 'clusters': [], 'apiVersion': '1', 'current-context': 'vagrant', 'contexts': []}.to_yaml)
      t.flush
      yield t.path
    end
  end

  def create_kubernetes_cluster
    Kubernetes::Cluster.any_instance.stubs(connection_valid?: true)
    Kubernetes::Cluster.create!(name: 'Foo', config_filepath: __FILE__, config_context: 'y')
  end

  private

  def read_file(file_name)
    File.read("#{Rails.root}/plugins/kubernetes/test/samples/#{file_name}")
  end
end
