DeployGroup.class_eval do
  belongs_to :kubernetes_cluster, class_name: 'Kubernetes::Cluster'
  validate :validate_kubernetes_namespace

  def kubernetes_namespace
    super || name.try(:parameterize, '-')
  end

  private

  def validate_kubernetes_namespace
    if kubernetes_cluster && !kubernetes_cluster.namespace_exists?(kubernetes_namespace)
      errors.add(:kubernetes_namespace, "does not exist")
    end
  end
end
