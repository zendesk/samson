# frozen_string_literal: true
class EnvironmentVariable < ActiveRecord::Base
  include GroupScope
  audited

  belongs_to :parent, polymorphic: true # Resource they are set on

  validates :name, presence: true

  class << self
    # preview parameter can be used to not raise an error,
    # but return a value with a helpful message
    # also used by an external plugin
    def env(project, deploy_group, preview: false)
      variables = project.environment_variables + project.environment_variable_groups.flat_map(&:environment_variables)
      variables.sort_by! { |ev| ev.send(:priority) }
      env = variables.each_with_object({}) do |ev, all|
        all[ev.name] = ev.value if !all[ev.name] && ev.send(:matches_scope?, deploy_group)
      end

      resolve_dollar_variables(env)
      resolve_secrets(project, deploy_group, env, preview: preview)

      env
    end

    private

    def resolve_dollar_variables(env)
      env.each_value do |value|
        value.gsub!(/\$\{(\w+)\}|\$(\w+)/) do |original|
          env[$1 || $2] || original
        end
      end
    end

    def resolve_secrets(project, deploy_group, env, preview:)
      resolver = Samson::Secrets::KeyResolver.new(project, Array(deploy_group))
      env.each_value do |value|
        if value.start_with?(TerminalExecutor::SECRET_PREFIX)
          key = value.sub(TerminalExecutor::SECRET_PREFIX, '')
          found = resolver.read(key)
          resolved =
            if preview
              found ? "#{value} ✓" : "#{value} X"
            else
              found.to_s
            end
          value.replace(resolved)
        end
      end
      resolver.verify! unless preview
    end
  end

  # used by `priority` from GroupScope
  def project?
    parent_type == "Project"
  end
end
