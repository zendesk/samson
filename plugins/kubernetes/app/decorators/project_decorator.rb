# frozen_string_literal: true
Project.class_eval do
  has_soft_deletion default_scope: true

  has_many :kubernetes_releases, class_name: 'Kubernetes::Release', dependent: nil
  has_many :kubernetes_roles, class_name: 'Kubernetes::Role', dependent: :destroy
  has_many :kubernetes_deploy_group_roles, class_name: 'Kubernetes::DeployGroupRole', dependent: :destroy
  has_many :kubernetes_usage_limits, class_name: 'Kubernetes::UsageLimit', dependent: :destroy

  scope :with_kubernetes_roles, -> { where(id: Kubernetes::Role.not_deleted.pluck(Arel.sql('distinct project_id'))) }
end
