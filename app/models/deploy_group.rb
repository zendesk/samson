# frozen_string_literal: true
class DeployGroup < ActiveRecord::Base
  include Permalinkable

  has_soft_deletion default_scope: true

  belongs_to :environment
  has_many :deploy_groups_stages
  has_many :stages, through: :deploy_groups_stages
  has_many :template_stages, -> { where(is_template: true) }, through: :deploy_groups_stages, source: :stage

  validates_presence_of :name, :environment_id
  validates_uniqueness_of :name, :env_value
  validates_format_of :env_value, with: /\A\w[-_:\w]*\w\z/
  before_validation :initialize_env_value, on: :create

  default_scope { order(:name) }

  after_save :touch_stages
  before_destroy :touch_stages
  after_destroy :destroy_deploy_groups_stages

  def self.enabled?
    ENV['DEPLOY_GROUP_FEATURE'].present?
  end

  def deploys
    Deploy.where(stage: stage_ids)
  end

  def long_name
    "#{name} (#{environment.name})"
  end

  def natural_order
    name.split(/(\d+)/).each_with_index.map { |x, i| i.odd? ? x.to_i : x }
  end

  private

  def permalink_base
    name
  end

  def touch_stages
    stages.update_all(updated_at: Time.now)
  end

  def initialize_env_value
    self.env_value = name.to_s.parameterize if env_value.blank?
  end

  # DeployGroupsStage has no ids so the default dependent: :destroy fails
  def destroy_deploy_groups_stages
    DeployGroupsStage.where(deploy_group_id: id).delete_all
  end
end
