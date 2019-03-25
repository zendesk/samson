# frozen_string_literal: true
class Kubernetes::UsageLimit < ActiveRecord::Base
  include GroupScope
  audited

  self.table_name = 'kubernetes_usage_limits'
  belongs_to :project, optional: true, inverse_of: :kubernetes_usage_limits
  belongs_to :scope, polymorphic: true, optional: true

  validates :cpu, :memory, presence: true
  validates :scope_id, uniqueness: {scope: [:scope_type, :project_id]}
  validate :validate_wildcard

  def self.most_specific(project, deploy_group)
    all.sort_by(&:priority).detect { |l| l.send(:matches?, project, deploy_group) }
  end

  private

  # used by `priority` from GroupScope
  def project?
    project_id
  end

  def matches?(project, deploy_group)
    (!project_id || project_id == project.id) && matches_scope?(deploy_group)
  end

  def validate_wildcard
    return if ENV["KUBERNETES_ALLOW_WILDCARD_LIMITS"] == "true"
    return if (cpu == 0 && memory == 0) || scope_id || project_id
    errors.add :base, "Non-zero limits without scope and project are not allowed"
  end
end
