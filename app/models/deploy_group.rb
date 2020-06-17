# frozen_string_literal: true
class DeployGroup < ActiveRecord::Base
  has_soft_deletion default_scope: true
  audited

  include Permalinkable
  include Lockable
  include SoftDeleteWithDestroy

  default_scope { order(:name_sortable) }

  belongs_to :environment, inverse_of: :deploy_groups
  belongs_to :vault_server, class_name: 'Samson::Secrets::VaultServer', optional: true, inverse_of: :deploy_groups
  has_many :deploy_groups_stages, dependent: :destroy
  has_many :stages, through: :deploy_groups_stages, inverse_of: :deploy_groups
  has_many :template_stages, -> { where(is_template: true) },
    through: :deploy_groups_stages, source: :stage, inverse_of: false

  delegate :production?, to: :environment

  validates :name, :environment_id, presence: true
  validates :name, :env_value, uniqueness: {case_sensitive: false}
  validates :env_value, format: {with: /\A\w[-:\w]*\w\z/}
  before_validation :initialize_env_value, on: :create
  before_validation :generated_name_sortable, if: :name_changed?
  validate :validate_vault_server_has_same_environment

  after_save :touch_stages
  before_soft_delete :validate_not_used

  def self.enabled?
    ENV['DEPLOY_GROUP_FEATURE'].present?
  end

  # faster alternative to stage_ids way of getting stage_ids
  def pluck_stage_ids
    deploy_groups_stages.pluck(:stage_id)
  end

  def locked_by?(lock)
    super || (lock.resource_type == "Environment" && lock.resource_equal?(environment))
  end

  def as_json(options = {})
    super({except: [:name_sortable]}.merge(options))
  end

  private

  def generated_name_sortable
    self.name_sortable = Samson::NaturalOrder.name_sortable(name)
  end

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
Samson::Hooks.load_decorators(DeployGroup)
