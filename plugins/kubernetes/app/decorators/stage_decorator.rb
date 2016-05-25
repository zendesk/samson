Stage.class_eval do
  validate :validate_deploy_groups_have_a_cluster, if: :kubernetes
  after_create :seed_kubernetes_roles

  private

  def validate_deploy_groups_have_a_cluster
    if kubernetes && bad = deploy_groups.reject(&:kubernetes_cluster).presence
      errors.add(
        :kubernetes,
        "Deploy groups need to have a cluster associated, but #{bad.map(&:name).join(', ')} did not."
      )
    end
  end

  def seed_kubernetes_roles
    Kubernetes::Role.seed! project, 'master' if kubernetes
  end
end
