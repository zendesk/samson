# frozen_string_literal: true
Deploy.class_eval do
  has_one :kubernetes_release, class_name: 'Kubernetes::Release'

  before_create :copy_kubernetes_from_stage

  private

  def copy_kubernetes_from_stage
    self.kubernetes = stage.try(:kubernetes)
    nil
  end
end
