module Kubernetes
  class DeployGroupRole < ActiveRecord::Base
    self.table_name = 'kubernetes_deploy_group_roles'
    belongs_to :project
    belongs_to :deploy_group
    validates :name, :ram, :cpu, :replicas, presence: true
  end
end
