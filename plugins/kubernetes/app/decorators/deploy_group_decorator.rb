DeployGroup.class_eval do
  has_one :cluster_deploy_group, class_name: 'Kubernetes::ClusterDeployGroup', foreign_key: :deploy_group_id
  has_one :kubernetes_cluster, class_name: 'Kubernetes::Cluster', through: :cluster_deploy_group, source: :cluster

  accepts_nested_attributes_for :cluster_deploy_group

  def kubernetes_namespace
    cluster_deploy_group.try(:namespace)
  end

end
