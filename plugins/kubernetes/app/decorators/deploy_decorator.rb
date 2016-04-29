Deploy.class_eval do
  before_create :copy_kubernetes_from_stage

  private

  def copy_kubernetes_from_stage
    self.kubernetes = stage.try(:kubernetes)
    nil
  end
end
