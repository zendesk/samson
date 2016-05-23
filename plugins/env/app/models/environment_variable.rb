class EnvironmentVariable < ActiveRecord::Base
  belongs_to :parent, polymorphic: true
  belongs_to :scope, polymorphic: true
  validates :name, presence: true
  validates :scope_type, inclusion: ["Environment", "DeployGroup", nil]

  class << self
    # preview parameter can be used to not raise an error,
    # but return a value with a helpful message
    # used by an external plugin
    def env(project, deploy_group, preview: false) # rubocop:disable Lint/UnusedMethodArgument
      variables = project.environment_variables + project.environment_variable_groups.flat_map(&:environment_variables)
      variables.sort_by! { |ev| ev.send :priority }
      env = variables.each_with_object({}) do |ev, all|
        all[ev.name] = ev.value if matches?(ev, deploy_group)
      end

      resolve_dollar_variables(env)
    end

    def env_deploygroup_array(include_all: true) # used by private plugin
      all = include_all ? [["All", nil]] : []
      envs = Environment.all.map { |env| [env.name, "Environment-#{env.id}"] }
      separator = [["----", nil]]
      deploy_groups = DeployGroup.all.map { |dg| [dg.name, "DeployGroup-#{dg.id}"] }
      all + envs + separator + deploy_groups
    end

    private

    def matches?(ev, deploy_group)
      return true unless ev.scope_id # for all
      return false unless deploy_group # unscoped -> no specific groups
      case ev.scope_type
      when "DeployGroup" then ev.scope_id == deploy_group.id # matches deploy group
      when "Environment" then ev.scope_id == deploy_group.environment_id # matches deploy group's environment
      else raise "Unsupported scope #{ev.scope_type}"
      end
    end

    def resolve_dollar_variables(env)
      env.each_value do |value|
        value.gsub!(/\$\{(\w+)\}|\$(\w+)/) do |original|
          env[$1 || $2] || original
        end
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
    result = []
    result << (parent_type == "Project" ? 1 : 0)
    result <<
      case scope_type
      when nil then 0
      when "Environment" then 1
      when "DeployGroup" then 2
      else raise "Unsupported type: #{scope_type}"
      end
  end
end
