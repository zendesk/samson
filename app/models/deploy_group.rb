class DeployGroup < ActiveRecord::Base
  include Permalinkable

  has_soft_deletion default_scope: true

  belongs_to :environment
  has_many :deploy_groups_stages
  has_many :stages, through: :deploy_groups_stages

  validates_presence_of :name, :environment_id
  validates_uniqueness_of :name, :env_value
  before_validation :initialize_env_value, on: :create

  default_scope { order(:name) }

  before_destroy :touch_stages
  after_save :touch_stages

  def self.enabled?
    ENV['DEPLOY_GROUP_FEATURE'].present?
  end

  def deploys
    Deploy.where(stage: stage_ids)
  end

  def long_name
    "#{name} (#{environment.name})"
  end

  private

  def permalink_base
    name
  end

  def touch_stages
    stages.update_all(updated_at: Time.now)
  end

  def initialize_env_value
    self.env_value = name if env_value.blank?
  end
end
