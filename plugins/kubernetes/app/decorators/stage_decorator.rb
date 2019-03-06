# frozen_string_literal: true
Stage.class_eval do
  validate :validate_deploy_groups_have_a_cluster, if: :kubernetes?

  before_save :clear_commands, if: :kubernetes?
  after_create :seed_kubernetes_roles
  validate :validate_not_using_non_kubernetes_rollback, if: :kubernetes?

  has_many :kubernetes_roles, class_name: "Kubernetes::StageRole", dependent: :destroy
  accepts_nested_attributes_for :kubernetes_roles,
    allow_destroy: true,
    reject_if: ->(a) { a[:kubernetes_role_id].blank? }

  private

  def validate_deploy_groups_have_a_cluster
    if kubernetes && bad = deploy_groups.reject(&:kubernetes_cluster).presence
      errors.add(
        :kubernetes,
        "Deploy groups need to have a cluster associated, but #{bad.map(&:name).join(', ')} did not."
      )
    end
  end

  def validate_not_using_non_kubernetes_rollback
    if allow_redeploy_previous_when_failed
      errors.add :allow_redeploy_previous_when_failed, "cannot be set for kubernetes stages"
    end
  end

  def seed_kubernetes_roles
    return unless kubernetes
    Kubernetes::Role.seed! project, 'master'
  rescue Samson::Hooks::UserError
    nil # ignore ... user can set this up later
  end

  def clear_commands
    stage_commands.clear
  end
end
