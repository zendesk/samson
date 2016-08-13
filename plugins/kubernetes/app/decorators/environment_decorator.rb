# frozen_string_literal: true
Environment.class_eval do
  has_many :cluster_deploy_groups, class_name: 'Kubernetes::ClusterDeployGroup', through: :deploy_groups
end
