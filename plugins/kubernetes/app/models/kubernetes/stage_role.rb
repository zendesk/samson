# frozen_string_literal: true

module Kubernetes
  class StageRole < ActiveRecord::Base
    self.table_name = 'kubernetes_stage_roles'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role', inverse_of: :stage_roles
    belongs_to :stage, inverse_of: :kubernetes_stage_roles
  end
end
