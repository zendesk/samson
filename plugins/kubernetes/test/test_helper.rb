require_relative '../../../test/test_helper'
require_relative '../lib/samson_kubernetes/hash_kuber_selector'
require 'celluloid/test'

class ActiveSupport::TestCase
  self.set_fixture_class kubernetes_releases: Kubernetes::Release
  self.set_fixture_class kubernetes_roles: Kubernetes::Role
  self.set_fixture_class kubernetes_clusters: Kubernetes::Cluster
  self.set_fixture_class kubernetes_cluster_deploy_groups: Kubernetes::ClusterDeployGroup
  self.set_fixture_class kubernetes_release_docs: Kubernetes::ReleaseDoc

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

  private

  def read_file(file_name)
    File.read("#{Rails.root}/plugins/kubernetes/test/samples/#{file_name}")
  end
end
