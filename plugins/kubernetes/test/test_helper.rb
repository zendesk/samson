# frozen_string_literal: true
require_relative '../../../test/test_helper'

class ActiveSupport::TestCase
  def with_example_kube_config
    Tempfile.create('config') do |t|
      config = {
        'apiVersion' => 'v1',
        'users' => nil,
        'clusters' => [
          {
            'name' => 'somecluster',
            'cluster' => {'server' => 'http://k8s.example.com'}
          }
        ],
        'contexts' => [
          {
            'name' => 'default',
            'context' => {'cluster' => 'somecluster', 'user' => ''}
          }
        ],
        'current-context' => 'default'
      }
      t.write(config.to_yaml)
      t.flush
      yield t.path
    end
  end

  def create_kubernetes_cluster(attributes = {})
    cluster = Kubernetes::Cluster.new({
      name: 'Foo',
      config_filepath: File.join(File.dirname(__FILE__), 'cluster_config.yml'),
      config_context: 'test'
    }.merge(attributes))
    cluster.save!(validate: false)
    cluster
  end

  def kubernetes_fake_raw_template
    role = Kubernetes::RoleConfigFile.new(
      read_kubernetes_sample_file('kubernetes_deployment.yml'),
      'config/app_server.yml',
      namespace: nil
    )
    Kubernetes::ReleaseDoc.any_instance.stubs(raw_template: role.elements)
  end

  def kubernetes_sample_file_path(file_name)
    "#{Rails.root}/plugins/kubernetes/test/samples/#{file_name}"
  end

  def read_kubernetes_sample_file(file_name)
    File.read(kubernetes_sample_file_path(file_name))
  end

  # https://github.com/abonas/kubeclient/pull/200
  # from kubernetes 1.2
  # this needs to be updated if we want to use a newer version of kubernetes
  # captured by opening kubeclient gem and dumping response inside of kubeclient/common.rb#discover

  KUBERNETES_VERSION_REPLIES = {
    "v1" => {
      "kind" => "APIResourceList",
      "resources" => [
        {"name" => "bindings", "namespaced" => true, "kind" => "Binding"},
        {"name" => "componentstatuses", "namespaced" => false, "kind" => "ComponentStatus"},
        {"name" => "configmaps", "namespaced" => true, "kind" => "ConfigMap"},
        {"name" => "endpoints", "namespaced" => true, "kind" => "Endpoints"},
        {"name" => "events", "namespaced" => true, "kind" => "Event"},
        {"name" => "limitranges", "namespaced" => true, "kind" => "LimitRange"},
        {"name" => "namespaces", "namespaced" => false, "kind" => "Namespace"},
        {"name" => "namespaces/finalize", "namespaced" => false, "kind" => "Namespace"},
        {"name" => "namespaces/status", "namespaced" => false, "kind" => "Namespace"},
        {"name" => "nodes", "namespaced" => false, "kind" => "Node"},
        {"name" => "nodes/proxy", "namespaced" => false, "kind" => "Node"},
        {"name" => "nodes/status", "namespaced" => false, "kind" => "Node"},
        {"name" => "persistentvolumeclaims", "namespaced" => true, "kind" => "PersistentVolumeClaim"},
        {"name" => "persistentvolumeclaims/status", "namespaced" => true, "kind" => "PersistentVolumeClaim"},
        {"name" => "persistentvolumes", "namespaced" => false, "kind" => "PersistentVolume"},
        {"name" => "persistentvolumes/status", "namespaced" => false, "kind" => "PersistentVolume"},
        {"name" => "pods", "namespaced" => true, "kind" => "Pod"},
        {"name" => "pods/attach", "namespaced" => true, "kind" => "Pod"},
        {"name" => "pods/binding", "namespaced" => true, "kind" => "Binding"},
        {"name" => "pods/exec", "namespaced" => true, "kind" => "Pod"},
        {"name" => "pods/log", "namespaced" => true, "kind" => "Pod"},
        {"name" => "pods/portforward", "namespaced" => true, "kind" => "Pod"},
        {"name" => "pods/proxy", "namespaced" => true, "kind" => "Pod"},
        {"name" => "pods/status", "namespaced" => true, "kind" => "Pod"},
        {"name" => "podtemplates", "namespaced" => true, "kind" => "PodTemplate"},
        {"name" => "replicationcontrollers", "namespaced" => true, "kind" => "ReplicationController"},
        {"name" => "replicationcontrollers/scale", "namespaced" => true, "kind" => "Scale"},
        {"name" => "replicationcontrollers/status", "namespaced" => true, "kind" => "ReplicationController"},
        {"name" => "resourcequotas", "namespaced" => true, "kind" => "ResourceQuota"},
        {"name" => "resourcequotas/status", "namespaced" => true, "kind" => "ResourceQuota"},
        {"name" => "secrets", "namespaced" => true, "kind" => "Secret"},
        {"name" => "serviceaccounts", "namespaced" => true, "kind" => "ServiceAccount"},
        {"name" => "services", "namespaced" => true, "kind" => "Service"},
        {"name" => "services/proxy", "namespaced" => true, "kind" => "Service"},
        {"name" => "services/status", "namespaced" => true, "kind" => "Service"}
      ]
    },
    "extensions/v1beta1" => {
      "kind" => "APIResourceList",
      "resources" => [
        {"name" => "daemonsets", "namespaced" => true, "kind" => "DaemonSet"},
        {"name" => "daemonsets/status", "namespaced" => true, "kind" => "DaemonSet"},
        {"name" => "deployments", "namespaced" => true, "kind" => "Deployment"},
        {"name" => "deployments/rollback", "namespaced" => true, "kind" => "DeploymentRollback"},
        {"name" => "deployments/scale", "namespaced" => true, "kind" => "Scale"},
        {"name" => "deployments/status", "namespaced" => true, "kind" => "Deployment"},
        {"name" => "ingresses", "namespaced" => true, "kind" => "Ingress"},
        {"name" => "ingresses/status", "namespaced" => true, "kind" => "Ingress"},
        {"name" => "jobs", "namespaced" => true, "kind" => "Job"},
        {"name" => "jobs/status", "namespaced" => true, "kind" => "Job"},
        {"name" => "replicasets", "namespaced" => true, "kind" => "ReplicaSet"},
        {"name" => "replicasets/scale", "namespaced" => true, "kind" => "Scale"},
        {"name" => "replicasets/status", "namespaced" => true, "kind" => "ReplicaSet"},
        {"name" => "replicationcontrollers", "namespaced" => true, "kind" => "ReplicationControllerDummy"},
        {"name" => "replicationcontrollers/scale", "namespaced" => true, "kind" => "Scale"}
      ]
    },
    "batch/v1" => {
      "kind" => "APIResourceList",
      "resources" => [
        {"name" => "jobs", "namespaced" => true, "kind" => "Job"}
      ]
    },
    "batch/v1beta1" => {
      "kind" => "APIResourceList",
      "resources" => [
        {"name" => "cronjobs", "namespaced" => true, "kind" => "CronJob"}
      ]
    },
    "apps/v1beta1" => {
      "kind" => "APIResourceList",
      "resources" => [
        {"name" => "statefulsets", "namespaced" => true, "kind" => "StatefulSet"}
      ]
    },
    "autoscaling/v1" => {
      "kind" => "APIResourceList",
      "resources" => [
        {"name" => "horizontalpodautoscalers", "namespaced" => true, "kind" => "HorizontalPodAutoscaler"},
        {"name" => "horizontalpodautoscalers/status", "namespaced" => true, "kind" => "HorizontalPodAutoscaler"},
      ]
    },
    "policy/v1beta1" => {
      "kind" => "APIResourceList",
      "resources" => [
        {"name" => "poddisruptionbudgets", "namespaced" => true, "kind" => "PodDisruptionBudget"}
      ]
    },
    "apiregistration.k8s.io/v1beta1" => {
      "kind" => "APIResourceList",
      "resources" => [
        {"name" => "apiservices", "namespaced" => true, "kind" => "APIService"}
      ]
    },
    "apiextensions.k8s.io/v1beta1" => {
      "kind" => "APIResourceList",
      "resources" => [
        {"name" => "customresourcedefinitions", "namespaced" => true, "kind" => "CustomResourceDefinition"}
      ]
    }
  }.freeze

  before do
    stub_request(:get, %r{http://foobar.server/(api/v1|apis/([a-z.\d]+/[a-z\d]+))$}).to_return do |request|
      version = request.uri.path.split('/', 3).last
      body = KUBERNETES_VERSION_REPLIES[version] || raise("Missing version stub for #{version}")
      {body: body.to_json}
    end

    stub_request(:get, 'http://foobar.server/version').to_return(body: '{"gitVersion": "v1.5.0"}')
  end
end
