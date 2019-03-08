# frozen_string_literal: true
class DeployGroup < ActiveRecord::Base
  has_soft_deletion default_scope: true unless self < SoftDeletion::Core # uncovered
  audited

  include Permalinkable
  include Lockable
  include SoftDeleteWithDestroy

  belongs_to :environment
  belongs_to :vault_server, class_name: 'Samson::Secrets::VaultServer', optional: true
  has_many :deploy_groups_stages, dependent: :destroy
  has_many :stages, through: :deploy_groups_stages
  has_many :template_stages, -> { where(is_template: true) }, through: :deploy_groups_stages, source: :stage

  delegate :production?, to: :environment

  validates_presence_of :name, :environment_id
  validates_uniqueness_of :name, :env_value
  validates_format_of :env_value, with: /\A\w[-:\w]*\w\z/
  before_validation :initialize_env_value, on: :create
  validate :validate_vault_server_has_same_environment

  after_save :touch_stages
  before_soft_delete :validate_not_used

  def self.enabled?
    ENV['DEPLOY_GROUP_FEATURE'].present?
  end

  def natural_order
    Samson::NaturalOrder.convert(name)
  end

  # faster alternative to stage_ids way of getting stage_ids
  def pluck_stage_ids
    deploy_groups_stages.pluck(:stage_id)
  end

  def locked_by?(lock)
    super || (lock.resource_type == "Environment" && lock.resource_equal?(environment))
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

  def validate_not_used
    return if deploy_groups_stages.empty?
    errors.add(:base, "Still being used")
    throw(:abort)
  end

  # Don't allow mixing of production and non-production vault servers
  def validate_vault_server_has_same_environment
    return unless vault_server_id_changed? && vault_server
    if vault_server.deploy_groups.any? { |dg| dg.production? != production? }
      errors.add :vault_server_id, "#{vault_server.name} can't mix production and non-production deploy groups"
    end
  end
end
