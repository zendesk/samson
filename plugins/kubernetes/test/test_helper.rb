require_relative '../../../test/test_helper'
require_relative '../lib/samson_kubernetes/hash_kuber_selector'

class ActiveSupport::TestCase
  self.set_fixture_class kubernetes_releases: Kubernetes::Release
  self.set_fixture_class kubernetes_release_groups: Kubernetes::ReleaseGroup
  self.set_fixture_class kubernetes_roles: Kubernetes::Role
end
