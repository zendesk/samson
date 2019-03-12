# frozen_string_literal: true
class Environment < ActiveRecord::Base
  has_soft_deletion default_scope: true
  audited

  include Lockable
  include Permalinkable
  include SoftDeleteWithDestroy

  has_many :deploy_groups, dependent: :destroy
  has_many :template_stages, -> { where(is_template: true) }, through: :deploy_groups, class_name: 'Stage'

  validates_presence_of :name
  validates_uniqueness_of :name

  # also used by private plugin
  class << self
    def env_deploy_group_array(include_all: true)
      scopes = include_all ? [["All", nil]] : []
      envs = Environment.all.map { |env| [env.name, "Environment-#{env.id}"] }
      scopes = scopes + scope_separator(' Environments ') + envs if envs.present?
      deploy_groups = DeployGroup.all.sort_by(&:natural_order).map { |dg| [dg.name, "DeployGroup-#{dg.id}"] }
      scopes = scopes + scope_separator(' Deploy Groups ') + deploy_groups if deploy_groups.present?
      scopes
    end

    def env_stage_deploy_group_array(project: nil, include_all: true)
      scopes = env_deploy_group_array(include_all: include_all)
      if (stages = project&.stages).present?
        scopes = scopes + scope_separator(' Stages ') + stages.map { |stage| [stage.name, "Stage-#{stage.id}"] }
      end
      scopes
    end

    private

    def scope_separator(name = '')
      [["---#{name}---", "disabled", {disabled: true}]]
    end
  end

  private

  def permalink_base
    name
  end
end
