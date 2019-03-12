# frozen_string_literal: true
module GroupScope
  def self.included(base)
    base.validates :scope_type, inclusion: ["Environment", "DeployGroup", "Stage", nil]
    base.belongs_to :scope, polymorphic: true, optional: true
  end

  def self.split(scoped_type_and_id)
    scoped_type_and_id.split("-", 2)
  end

  # used to assign direct from form values
  def scope_type_and_id=(value)
    self.scope_type, self.scope_id = GroupScope.split(value.to_s)
  end

  def scope_type_and_id
    return unless scope_type && scope_id
    "#{scope_type}-#{scope_id}"
  end

  def matches_scope?(deploy_group, stage = nil)
    return true unless scope_id # for all
    return false unless deploy_group # unscoped -> no specific groups

    case scope_type
    when "DeployGroup" then scope_id == deploy_group.id # matches deploy group
    when "Environment" then scope_id == deploy_group.environment_id # matches deploy group's environment
    when "Stage"       then stage && scope_id == stage.id
    else raise "Unsupported scope #{scope_type}"
    end
  end

  def priority
    [
      (project? ? 0 : 1),
      case scope_type
      when nil then 3
      when "Environment" then 2
      when "DeployGroup" then 1
      when "Stage"       then 0
      else raise "Unsupported scope #{scope_type}"
      end
    ]
  end
end
