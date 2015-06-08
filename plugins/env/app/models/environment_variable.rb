class EnvironmentVariable < ActiveRecord::Base
  belongs_to :parent, polymorphic: true
  belongs_to :scope, polymorphic: true
  validates :name, presence: true
  validates :scope_type, inclusion: ["Environment", "DeployGroup", nil]

  def self.env(project, deploy_group)
    variables = project.environment_variables + project.environment_variable_groups.flat_map(&:environment_variables)
    variables.sort_by! { |ev| [ev.parent_type == "Project" ? 1 : 0, ev.send(:priority)] } # TODO move into priority
    env = variables.each_with_object({}) do |ev, all|
      match = (
        !ev.scope_id || # for all
        (deploy_group && (
          (ev.scope_type == "DeployGroup" && ev.scope_id == deploy_group.id) || # matches deploy group
          (ev.scope_type == "Environment" && ev.scope_id == deploy_group.environment_id) # matches deploy group's environment
        ))
      )
      all[ev.name] = ev.value if match
    end

    env.each_value do |value|
      value.gsub!(/\$\{(\w+)\}|\$(\w+)/) do |original|
        env[$1 || $2] || original
      end
    end
  end

  # used to assign direct from form values
  def scope_type_and_id=(value)
    self.scope_type, self.scope_id = value.to_s.split("-")
  end

  def scope_type_and_id
    return unless scope_type && scope_id
    "#{scope_type}-#{scope_id}"
  end

  private

  def priority
    case scope_type
    when nil then 0
    when "Environment" then 1
    when "DeployGroup" then 2
    else raise "Unsupported type: #{scope_type}"
    end
  end
end
