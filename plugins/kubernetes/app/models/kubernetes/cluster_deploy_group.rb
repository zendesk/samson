# frozen_string_literal: true
module Kubernetes
  class ClusterDeployGroup < ActiveRecord::Base
    self.table_name = 'kubernetes_cluster_deploy_groups'

    belongs_to :cluster, class_name: 'Kubernetes::Cluster', foreign_key: :kubernetes_cluster_id
    belongs_to :deploy_group, inverse_of: :cluster_deploy_group

    validates :cluster, presence: true
    validates :deploy_group, presence: true
    validates :namespace, presence: true
    validate :validate_namespace_exists

    private

    def validate_namespace_exists
      if cluster && namespace.present? && !cluster.namespace_exists?(namespace)
        errors.add(:namespace, "named '#{namespace}' does not exist")
      end
    end
  end
end
