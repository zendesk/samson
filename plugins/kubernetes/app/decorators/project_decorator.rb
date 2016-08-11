# frozen_string_literal: true
Project.class_eval do
  has_many :kubernetes_releases, class_name: 'Kubernetes::Release'
  has_many :kubernetes_roles, class_name: 'Kubernetes::Role', dependent: :destroy
  has_many :kubernetes_deploy_group_roles, class_name: 'Kubernetes::DeployGroupRole'

  scope :with_kubernetes_roles, -> { where(id: Kubernetes::Role.not_deleted.pluck('distinct project_id')) }
end
