# frozen_string_literal: true
require 'yaml'

# example setup for docker-for-mac with kubernetes
# running without validations it works even when docker is not running
project = Project.create!(
  name: "Example-kubernetes",
  repository_url: "https://github.com/samson-test-org/example-kubernetes.git"
)

master = Environment.find_by_name!("Master")
groupk = DeployGroup.create!(
  name: 'GroupK',
  environment: master
)

k8s_config_path = ENV['KUBECONFIG'] || "#{ENV['HOME']}/.kube/config"
k8s_context = 'docker-for-desktop'
k8s_context = YAML.load_file(k8s_config_path).fetch('current-context') if File.exist?(k8s_config_path)
cluster = Kubernetes::Cluster.new(
  name: "local",
  description: "setup via seeds",
  config_filepath: k8s_config_path,
  config_context: k8s_context
)
cluster.save!(validate: false)

Kubernetes::ClusterDeployGroup.new(
  cluster: cluster,
  deploy_group: groupk,
  namespace: 'default'
).save!(validate: false)

# rails 5.2.1 bug that runs validations again
# TODO: report issue or remove and see if test/integration/tasks_test.rb still fails
groupk = groupk.class.find(groupk.id)

Stage.new(
  name: 'Master',
  project: project,
  deploy_groups: [groupk],
  kubernetes: true,
  permalink: 'master'
).save!(validate: false)

["migrate", "server"].each do |name|
  role = Kubernetes::Role.new(
    name: name,
    project: project
  )
  if name == "server"
    role.service_name = "example-server"
  end
  role.save!
  Kubernetes::DeployGroupRole.create!(
    project: project,
    deploy_group: groupk,
    replicas: (name == "server" ? 2 : 1),
    kubernetes_role: role,
    requests_cpu: 0.1,
    requests_memory: 100,
    limits_cpu: 0.3,
    limits_memory: 300
  )
end

# this assumes env plugin is used too
EnvironmentVariable.create!(parent: project, name: "RAILS_ENV", value: "development")
