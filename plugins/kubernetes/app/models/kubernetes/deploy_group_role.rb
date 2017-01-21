# frozen_string_literal: true
module Kubernetes
  class DeployGroupRole < ActiveRecord::Base
    self.table_name = 'kubernetes_deploy_group_roles'

    has_paper_trail skip: [:updated_at, :created_at]

    belongs_to :project
    belongs_to :deploy_group
    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'

    validates :ram, :cpu, :replicas, presence: true
    validates :cpu, numericality: { greater_than: 0 }
    validates :ram, numericality: { greater_than_or_equal_to: 4 }

    # The matrix is a list of deploy group and its roles + deploy-group-roles
    def self.matrix(stage)
      project_dg_roles = Kubernetes::DeployGroupRole.where(
        project_id: stage.project_id,
        deploy_group_id: stage.deploy_groups.map(&:id)
      ).to_a
      roles = stage.project.kubernetes_roles.not_deleted.sort_by(&:name)

      stage.deploy_groups.sort_by(&:natural_order).map do |deploy_group|
        dg_roles = project_dg_roles.select { |r| r.deploy_group_id == deploy_group.id }
        role_pairs = roles.map do |role|
          [role, dg_roles.detect { |r| r.kubernetes_role_id == role.id }]
        end
        [deploy_group, role_pairs]
      end
    end

    # add deploy group roles for everything missing from the matrix
    # returns:
    #  - everything was created: true
    #  - some could not be created because of missing configs: false
    #  - failed to create because of unknown errors: raises
    def self.seed!(stage)
      missing = matrix(stage).each_with_object([]) do |(deploy_group, roles), all|
        roles.each do |role, dg_role|
          all << [deploy_group, role] unless dg_role
        end
      end

      missing.map do |deploy_group, role|
        next unless defaults = role.defaults

        create!(
          project: stage.project,
          deploy_group: deploy_group,
          kubernetes_role: role,
          replicas: defaults.fetch(:replicas),
          cpu: defaults.fetch(:cpu),
          ram: defaults.fetch(:ram)
        )
      end.all?
    end
  end
end
