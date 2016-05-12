# -*- encoding: utf-8 -*-
# stub: kubeclient 1.1.3 ruby lib

Gem::Specification.new do |s|
  s.name = "kubeclient"
  s.version = "1.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Alissa Bonas"]
  s.date = "2016-05-11"
  s.description = "A client for Kubernetes REST api"
  s.email = ["abonas@redhat.com"]
  s.files = [".gitignore", ".rubocop.yml", ".travis.yml", "Gemfile", "LICENSE.txt", "README.md", "Rakefile", "kubeclient.gemspec", "lib/kubeclient.rb", "lib/kubeclient/common.rb", "lib/kubeclient/config.rb", "lib/kubeclient/entity_list.rb", "lib/kubeclient/kube_exception.rb", "lib/kubeclient/version.rb", "lib/kubeclient/watch_notice.rb", "lib/kubeclient/watch_stream.rb", "test/cassettes/kubernetes_guestbook.yml", "test/config/allinone.kubeconfig", "test/config/external-ca.pem", "test/config/external-cert.pem", "test/config/external-key.rsa", "test/config/external.kubeconfig", "test/config/nouser.kubeconfig", "test/json/component_status.json", "test/json/component_status_list.json", "test/json/created_endpoint.json", "test/json/created_namespace.json", "test/json/created_secret.json", "test/json/created_service.json", "test/json/empty_pod_list.json", "test/json/endpoint_list.json", "test/json/entity_list.json", "test/json/event_list.json", "test/json/limit_range.json", "test/json/limit_range_list.json", "test/json/namespace.json", "test/json/namespace_exception.json", "test/json/namespace_list.json", "test/json/node.json", "test/json/node_list.json", "test/json/persistent_volume.json", "test/json/persistent_volume_claim.json", "test/json/persistent_volume_claim_list.json", "test/json/persistent_volume_claims_nil_items.json", "test/json/persistent_volume_list.json", "test/json/pod.json", "test/json/pod_list.json", "test/json/replication_controller.json", "test/json/replication_controller_list.json", "test/json/resource_quota.json", "test/json/resource_quota_list.json", "test/json/secret_list.json", "test/json/service.json", "test/json/service_account.json", "test/json/service_account_list.json", "test/json/service_illegal_json_404.json", "test/json/service_list.json", "test/json/service_patch.json", "test/json/service_update.json", "test/json/versions_list.json", "test/json/watch_stream.json", "test/test_component_status.rb", "test/test_config.rb", "test/test_endpoint.rb", "test/test_guestbook_go.rb", "test/test_helper.rb", "test/test_kubeclient.rb", "test/test_limit_range.rb", "test/test_namespace.rb", "test/test_node.rb", "test/test_persistent_volume.rb", "test/test_persistent_volume_claim.rb", "test/test_pod.rb", "test/test_pod_log.rb", "test/test_replication_controller.rb", "test/test_resource_quota.rb", "test/test_secret.rb", "test/test_service.rb", "test/test_service_account.rb", "test/test_watch.rb", "test/txt/pod_log.txt", "test/valid_token_file"]
  s.homepage = "https://github.com/abonas/kubeclient"
  s.licenses = ["MIT"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0")
  s.rubygems_version = "2.4.5.1"
  s.summary = "A client for Kubernetes REST api"
  s.test_files = ["test/cassettes/kubernetes_guestbook.yml", "test/config/allinone.kubeconfig", "test/config/external-ca.pem", "test/config/external-cert.pem", "test/config/external-key.rsa", "test/config/external.kubeconfig", "test/config/nouser.kubeconfig", "test/json/component_status.json", "test/json/component_status_list.json", "test/json/created_endpoint.json", "test/json/created_namespace.json", "test/json/created_secret.json", "test/json/created_service.json", "test/json/empty_pod_list.json", "test/json/endpoint_list.json", "test/json/entity_list.json", "test/json/event_list.json", "test/json/limit_range.json", "test/json/limit_range_list.json", "test/json/namespace.json", "test/json/namespace_exception.json", "test/json/namespace_list.json", "test/json/node.json", "test/json/node_list.json", "test/json/persistent_volume.json", "test/json/persistent_volume_claim.json", "test/json/persistent_volume_claim_list.json", "test/json/persistent_volume_claims_nil_items.json", "test/json/persistent_volume_list.json", "test/json/pod.json", "test/json/pod_list.json", "test/json/replication_controller.json", "test/json/replication_controller_list.json", "test/json/resource_quota.json", "test/json/resource_quota_list.json", "test/json/secret_list.json", "test/json/service.json", "test/json/service_account.json", "test/json/service_account_list.json", "test/json/service_illegal_json_404.json", "test/json/service_list.json", "test/json/service_patch.json", "test/json/service_update.json", "test/json/versions_list.json", "test/json/watch_stream.json", "test/test_component_status.rb", "test/test_config.rb", "test/test_endpoint.rb", "test/test_guestbook_go.rb", "test/test_helper.rb", "test/test_kubeclient.rb", "test/test_limit_range.rb", "test/test_namespace.rb", "test/test_node.rb", "test/test_persistent_volume.rb", "test/test_persistent_volume_claim.rb", "test/test_pod.rb", "test/test_pod_log.rb", "test/test_replication_controller.rb", "test/test_resource_quota.rb", "test/test_secret.rb", "test/test_service.rb", "test/test_service_account.rb", "test/test_watch.rb", "test/txt/pod_log.txt", "test/valid_token_file"]

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>, ["~> 1.6"])
      s.add_development_dependency(%q<rake>, ["~> 10.0"])
      s.add_development_dependency(%q<minitest>, [">= 0"])
      s.add_development_dependency(%q<webmock>, ["~> 1.24.2"])
      s.add_development_dependency(%q<vcr>, [">= 0"])
      s.add_development_dependency(%q<rubocop>, ["= 0.30.0"])
      s.add_runtime_dependency(%q<rest-client>, [">= 0"])
      s.add_runtime_dependency(%q<activesupport>, [">= 0"])
      s.add_runtime_dependency(%q<recursive-open-struct>, ["= 1.0.0"])
      s.add_runtime_dependency(%q<http>, ["= 0.9.8"])
    else
      s.add_dependency(%q<bundler>, ["~> 1.6"])
      s.add_dependency(%q<rake>, ["~> 10.0"])
      s.add_dependency(%q<minitest>, [">= 0"])
      s.add_dependency(%q<webmock>, ["~> 1.24.2"])
      s.add_dependency(%q<vcr>, [">= 0"])
      s.add_dependency(%q<rubocop>, ["= 0.30.0"])
      s.add_dependency(%q<rest-client>, [">= 0"])
      s.add_dependency(%q<activesupport>, [">= 0"])
      s.add_dependency(%q<recursive-open-struct>, ["= 1.0.0"])
      s.add_dependency(%q<http>, ["= 0.9.8"])
    end
  else
    s.add_dependency(%q<bundler>, ["~> 1.6"])
    s.add_dependency(%q<rake>, ["~> 10.0"])
    s.add_dependency(%q<minitest>, [">= 0"])
    s.add_dependency(%q<webmock>, ["~> 1.24.2"])
    s.add_dependency(%q<vcr>, [">= 0"])
    s.add_dependency(%q<rubocop>, ["= 0.30.0"])
    s.add_dependency(%q<rest-client>, [">= 0"])
    s.add_dependency(%q<activesupport>, [">= 0"])
    s.add_dependency(%q<recursive-open-struct>, ["= 1.0.0"])
    s.add_dependency(%q<http>, ["= 0.9.8"])
  end
end
