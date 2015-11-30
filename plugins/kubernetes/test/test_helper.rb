require_relative '../../../test/test_helper'
require_relative '../lib/samson_kubernetes/hash_kuber_selector'
require 'celluloid/test'

class ActiveSupport::TestCase
  self.set_fixture_class kubernetes_releases: Kubernetes::Release
  self.set_fixture_class kubernetes_roles: Kubernetes::Role
  self.set_fixture_class kubernetes_clusters: Kubernetes::Cluster

  def parse_role_config_file(file_name)
    File.read("#{Rails.root}/plugins/kubernetes/test/samples/#{file_name}.yml")
  end
end
