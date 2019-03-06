# frozen_string_literal: true

module Kubernetes
  class StageRole < ActiveRecord::Base
    self.table_name = 'kubernetes_stage_roles'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    belongs_to :stage
  end
end
