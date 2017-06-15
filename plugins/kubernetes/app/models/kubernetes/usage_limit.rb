# frozen_string_literal: true
class Kubernetes::UsageLimit < ActiveRecord::Base
  include GroupScope
  audited

  self.table_name = 'kubernetes_usage_limits'
  belongs_to :project, optional: true
  belongs_to :scope, polymorphic: true, optional: true

  validates :cpu, :memory, presence: true
  validates :scope_id, uniqueness: {scope: [:scope_type, :project_id]}

  def self.most_specific(project, deploy_group)
    all.sort_by { |l| l.send :priority }.detect { |l| l.send(:matches?, project, deploy_group) }
  end

  private

  # used by `priority` from GroupScope
  def project?
    project_id
  end

  def matches?(project, deploy_group)
    (!project_id || project_id == project.id) && matches_scope?(deploy_group)
  end
end
