module Kubernetes
  class DeployGroupRole < ActiveRecord::Base
    self.table_name = 'kubernetes_deploy_group_roles'
    belongs_to :project
    belongs_to :deploy_group
    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    validates :ram, :cpu, :replicas, presence: true

    # The matrix is a list of deploy group and its roles + deploy-group-roles
    def self.matrix(stage)
      project_dg_roles = Kubernetes::DeployGroupRole.where(
        project_id: stage.project_id,
        deploy_group_id: stage.deploy_groups.map(&:id)
      ).to_a
      roles = stage.project.kubernetes_roles.sort_by(&:name)

      stage.deploy_groups.sort_by(&:natural_order).map do |deploy_group|
        dg_roles = project_dg_roles.select { |r| r.deploy_group_id == deploy_group.id }
        role_pairs = roles.map do |role|
          [role, dg_roles.detect { |r| r.kubernetes_role_id == role.id }]
        end
        [deploy_group, role_pairs]
      end
    end

    # add deploy group roles for everything missing from the matrix
    def self.seed!(stage)
      missing = matrix(stage).each_with_object([]) do |(deploy_group, roles), missing|
        roles.each do |role, dg_role|
          missing << [deploy_group, role] unless dg_role
        end
      end

      missing.map do |deploy_group, role|
        next unless raw_template = stage.project.repository.file_content(role.config_file, 'HEAD')
        objects = Array.wrap(Kubernetes::Util.parse_file(raw_template, role.config_file))
        next unless deploy = objects.detect { |o| ['Deployment', 'DaemonSet'].include?(o.fetch('kind')) }

        replicas = deploy['spec']['replicas']

        next unless limits = deploy['spec']['template']['spec']['containers'].first['resources'].try(:[], 'limits')
        cpu = limits['cpu'].to_i / 1000.0 # 250m -> 0.25
        ram = limits['ram'].to_i # 200Mi -> 200

        create!(
          project: stage.project,
          deploy_group: deploy_group,
          kubernetes_role: role,
          replicas: replicas,
          cpu: cpu,
          ram: ram
        )
      end.all?
    end
  end
end
