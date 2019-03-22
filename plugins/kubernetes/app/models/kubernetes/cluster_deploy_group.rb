# frozen_string_literal: true
module Kubernetes
  class ClusterDeployGroup < ActiveRecord::Base
    self.table_name = 'kubernetes_cluster_deploy_groups'

    belongs_to :cluster,
      class_name: 'Kubernetes::Cluster', foreign_key: :kubernetes_cluster_id, inverse_of: :cluster_deploy_groups
    belongs_to :deploy_group, inverse_of: :cluster_deploy_group

    validates :cluster, presence: true
    validates :deploy_group, presence: true
    validates :namespace, presence: true
    validate :validate_namespace_exists

    private

    def validate_namespace_exists
      return if !cluster || namespace.blank?

      begin
        namespaces = cluster.namespaces
        unless namespaces.include?(namespace)
          errors.add(:namespace, "named '#{namespace}' does not exist, found: #{namespaces.join(", ")}")
        end
      rescue *SamsonKubernetes.connection_errors => e
        errors.add(:namespace, "error looking up namespaces. Cause: #{e.message}")
      end
    end
  end
end
