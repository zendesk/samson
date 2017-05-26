# frozen_string_literal: true
class Kubernetes::UsageLimit < ActiveRecord::Base
  include GroupScope

  self.table_name = 'kubernetes_usage_limits'
  belongs_to :project, optional: true
  belongs_to :scope, polymorphic: true, optional: true

  validates :cpu, :memory, presence: true
end
