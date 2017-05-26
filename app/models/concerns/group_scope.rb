# frozen_string_literal: true
module GroupScope
  def self.included(base)
    base.validates :scope_type, inclusion: ["Environment", "DeployGroup", nil]
    base.belongs_to :scope, polymorphic: true, optional: true
  end

  # used to assign direct from form values
  def scope_type_and_id=(value)
    self.scope_type, self.scope_id = value.to_s.split("-")
  end

  def scope_type_and_id
    return unless scope_type && scope_id
    "#{scope_type}-#{scope_id}"
  end
end
