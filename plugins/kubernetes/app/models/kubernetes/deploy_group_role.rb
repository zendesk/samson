module Kubernetes
  class DeployGroupRole < ActiveRecord::Base
    self.table_name = 'kubernetes_deploy_group_roles'
    belongs_to :project
    belongs_to :deploy_group
    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    validates :ram, :cpu, :replicas, presence: true
  end
end
