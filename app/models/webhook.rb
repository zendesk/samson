# frozen_string_literal: true
class Webhook < ActiveRecord::Base
  has_soft_deletion default_scope: true
  include SoftDeleteWithDestroy

  validates :branch, uniqueness: {
    scope: [:stage_id],
    conditions: -> { where("deleted_at IS NULL") },
    message: "one webhook per (stage, branch) combination."
  }
  validate :validate_not_auto_deploying_without_buddy

  belongs_to :project, inverse_of: :webhooks
  belongs_to :stage, inverse_of: :webhooks

  def self.for_branch(branch)
    where(branch: ['', branch])
  end

  def self.for_source(service_type, service_name)
    where(source: ['any', "any_#{service_type}", service_name])
  end

  def self.source_matches?(release_source, service_type, service_name)
    release_source == 'any' || release_source == "any_#{service_type}" || release_source == service_name
  end

  private

  def validate_not_auto_deploying_without_buddy
    if stage&.deploy_requires_approval?
      errors.add(:stage, "cannot be used for a stage the requires approval")
    end
  end
end
