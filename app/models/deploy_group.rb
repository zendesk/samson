# frozen_string_literal: true
class DeployGroup < ActiveRecord::Base
  has_soft_deletion default_scope: true
  has_paper_trail skip: [:updated_at, :created_at]

  include Permalinkable

  belongs_to :environment
  belongs_to :vault_server, class_name: 'Samson::Secrets::VaultServer'
  has_many :deploy_groups_stages
  has_many :stages, through: :deploy_groups_stages
  has_many :template_stages, -> { where(is_template: true) }, through: :deploy_groups_stages, source: :stage

  delegate :production?, to: :environment

  validates_presence_of :name, :environment_id
  validates_uniqueness_of :name, :env_value
  validates_format_of :env_value, with: /\A\w[-:\w]*\w\z/
  before_validation :initialize_env_value, on: :create
  validate :validate_vault_server_has_same_environment

  after_save :touch_stages
  before_destroy :touch_stages
  after_destroy :destroy_deploy_groups_stages

  def self.enabled?
    ENV['DEPLOY_GROUP_FEATURE'].present?
  end

  def deploys
    Deploy.where(stage: stage_ids)
  end

  def natural_order
    Samson::NaturalOrder.convert(name)
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

  # Don't allow mixing of production and non-production vault servers
  def validate_vault_server_has_same_environment
    return unless vault_server_id_changed? && vault_server
    if vault_server.deploy_groups.any? { |dg| dg.production? != production? }
      errors.add :vault_server_id, "#{vault_server.name} can't mix production and non-production deploy groups"
    end
  end
end
