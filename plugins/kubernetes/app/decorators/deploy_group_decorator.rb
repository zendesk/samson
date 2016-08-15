# frozen_string_literal: true
DeployGroup.class_eval do
  has_one(
    :cluster_deploy_group,
    class_name: 'Kubernetes::ClusterDeployGroup',
    foreign_key: :deploy_group_id,
    inverse_of: :deploy_group
  )
  has_one :kubernetes_cluster, class_name: 'Kubernetes::Cluster', through: :cluster_deploy_group, source: :cluster

  accepts_nested_attributes_for(
    :cluster_deploy_group,
    allow_destroy: true,
    update_only: true,
    reject_if: lambda { |h| h[:kubernetes_cluster_id].blank? }
  )

  def kubernetes_namespace
    cluster_deploy_group.try(:namespace)
  end
end
