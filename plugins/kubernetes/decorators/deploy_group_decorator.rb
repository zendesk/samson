# frozen_string_literal: true
DeployGroup.class_eval do
  has_one(
    :cluster_deploy_group,
    class_name: 'Kubernetes::ClusterDeployGroup',
    inverse_of: :deploy_group,
    dependent: :destroy
  )
  has_one :kubernetes_cluster,
    class_name: 'Kubernetes::Cluster', through: :cluster_deploy_group, source: :cluster, inverse_of: :deploy_groups
  has_many :kubernetes_deploy_group_roles, class_name: 'Kubernetes::DeployGroupRole', dependent: :destroy
  has_many :kubernetes_usage_limits,
    class_name: 'Kubernetes::UsageLimit', dependent: :destroy, inverse_of: :scope, as: :scope

  accepts_nested_attributes_for(
    :cluster_deploy_group,
    allow_destroy: true,
    reject_if: ->(h) do
      empty = h[:kubernetes_cluster_id].blank?
      if h[:id]
        h[:_destroy] = true if empty # user removed cluster -> delete connection
        false
      else
        empty
      end
    end
  )

  def kubernetes_namespace
    cluster_deploy_group&.namespace
  end
end
