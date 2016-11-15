# frozen_string_literal: true
Stage.class_eval do
  validate :validate_deploy_groups_have_a_cluster, if: :kubernetes

  before_save :clear_commands, if: :kubernetes
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
    return unless kubernetes
    Kubernetes::Role.seed! project, 'master'
  rescue Samson::Hooks::UserError
    nil # ignore ... user can set this up later
  end

  def clear_commands
    commands.clear
  end
end
