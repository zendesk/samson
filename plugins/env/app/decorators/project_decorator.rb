# frozen_string_literal: true
class Project
  include AcceptsEnvironmentVariables

  has_many :project_environment_variable_groups
  has_many :environment_variable_groups, through: :project_environment_variable_groups, dependent: :destroy

  attr_accessor :previous_environment_variables

  class Trail < PaperTrail::RecordTrail
    attr_accessor :command_ids_changed

    # overwrites paper_trail to record when command_ids were changed but not trigger multiple versions per save
    def changed_notably?
      super || @record.environment_variables_changed?
    end

    # overwrites paper_trail to record script
    def object_attrs_for_paper_trail
      super.merge('env' => @record.previous_environment_variables)
    end
  end

  def paper_trail
    Trail.new(self)
  end

  def assign_attributes(*)
    self.previous_environment_variables ||= serialize_environment_variables
    super
  end

  def environment_variables_changed?
    previous_environment_variables != serialize_environment_variables
  end

  private

  # Note: env and deploy-group names could possibly not be unique, but that's what the UI shows too
  # TODO: sort like we sort in the UI
  # TODO: diffing in versions UI
  def serialize_environment_variables
    environment_variables.map do |var|
      "#{var.name}=#{var.value.inspect} # #{var.scope&.name || "All"}"
    end.join("\n")
  end
end
