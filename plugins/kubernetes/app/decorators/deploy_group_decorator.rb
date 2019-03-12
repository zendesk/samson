# frozen_string_literal: true
DeployGroup.class_eval do
  has_soft_deletion default_scope: true

  has_one(
    :cluster_deploy_group,
    class_name: 'Kubernetes::ClusterDeployGroup',
    foreign_key: :deploy_group_id,
    inverse_of: :deploy_group,
    dependent: :destroy
  )
  has_one :kubernetes_cluster, class_name: 'Kubernetes::Cluster', through: :cluster_deploy_group, source: :cluster
  has_many :kubernetes_deploy_group_roles, class_name: 'Kubernetes::DeployGroupRole', dependent: :destroy

  accepts_nested_attributes_for(
    :cluster_deploy_group,
    allow_destroy: true,
    update_only: true,
    reject_if: ->(h) { h[:kubernetes_cluster_id].blank? }
  )

  def kubernetes_namespace
    cluster_deploy_group&.namespace
  end
end
