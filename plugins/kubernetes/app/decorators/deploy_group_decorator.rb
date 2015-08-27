DeployGroup.class_eval do
  belongs_to :kubernetes_cluster, class_name: 'Kubernetes::Cluster'

  def kubernetes_namespace
    super || name.parameterize('-')
  end
end
