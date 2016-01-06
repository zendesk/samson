module Kubernetes
  class Role < ActiveRecord::Base
    self.table_name = 'kubernetes_roles'

    has_soft_deletion default_scope: true

    belongs_to :project, inverse_of: :roles

    DEPLOY_STRATEGIES = %w(RollingUpdate Recreate)

    validates :project, presence: true
    validates :name, presence: true
    validates :deploy_strategy, presence: true, inclusion: DEPLOY_STRATEGIES
    validates :replicas, presence: true, numericality: { greater_than: 0 }
    validates :ram, presence: true, numericality: { greater_than: 0 }
    validates :cpu, presence: true, numericality: { greater_than: 0 }

    def label_name
      name.parameterize('-')
    end

    def ram_with_units
      "#{ram}Mi" if ram.present?
    end

    def has_service?
      service_name.present?
    end

    def service_for(deploy_group)
      Kubernetes::Service.new(role: self, deploy_group: deploy_group) if has_service?
    end
  end
end
