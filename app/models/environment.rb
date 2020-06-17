# frozen_string_literal: true
class Environment < ActiveRecord::Base
  has_soft_deletion default_scope: true
  audited

  include Lockable
  include Permalinkable
  include SoftDeleteWithDestroy

  has_many :deploy_groups, dependent: :destroy
  has_many :template_stages, -> { where(is_template: true) },
    through: :deploy_groups, class_name: 'Stage', inverse_of: false

  validates :name, presence: true
  validates :name, uniqueness: {case_sensitive: false}

  # also used by private plugin
  def self.env_deploy_group_array(include_all: true)
    all = include_all ? [["All", nil]] : []
    envs = Environment.all.map { |env| [env.name, "Environment-#{env.id}"] }
    separator = [["----", "disabled", {disabled: true}]]
    deploy_groups = DeployGroup.select(:name, :id).map { |dg| [dg.name, "DeployGroup-#{dg.id}"] }
    all + envs + separator + deploy_groups
  end

  private

  def permalink_base
    name
  end
end
Samson::Hooks.load_decorators(Environment)
