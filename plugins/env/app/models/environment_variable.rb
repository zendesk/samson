# frozen_string_literal: true
require 'validates_lengths_from_database'

class EnvironmentVariable < ActiveRecord::Base
  include GroupScope
  audited

  belongs_to :parent, polymorphic: true # Resource they are set on

  validates :name, presence: true

  include ValidatesLengthsFromDatabase
  validates_lengths_from_database only: :value

  class << self
    # preview parameter can be used to not raise an error,
    # but return a value with a helpful message
    # also used by an external plugin
    def env(project, deploy_group, preview: false)
      variables = nested_variables(project)
      variables.sort_by! { |ev| ev.send(:priority) }
      env = variables.each_with_object({}) do |ev, all|
        all[ev.name] = ev.value if !all[ev.name] && ev.send(:matches_scope?, deploy_group)
      end

      resolve_dollar_variables(env)
      resolve_secrets(project, deploy_group, env, preview: preview)

      env
    end

    # scopes is given as argument since it needs to be cached
    def sort_by_scopes(variables, scopes)
      variables.sort_by { |x| [x.name, scopes.index { |_, s| s == x.scope_type_and_id } || 999] }
    end

    def nested_variables(project)
      project.environment_variables + project.environment_variable_groups.flat_map(&:environment_variables)
    end

    private

    def resolve_dollar_variables(env)
      env.each do |k, value|
        env[k] = value.gsub(/\$\{(\w+)\}|\$(\w+)/) { |original| env[$1 || $2] || original }
      end
    end

    def resolve_secrets(project, deploy_group, env, preview:)
      resolver = Samson::Secrets::KeyResolver.new(project, Array(deploy_group))
      env.each do |key, value|
        if value.start_with?(TerminalExecutor::SECRET_PREFIX)
          secret_key = value.sub(TerminalExecutor::SECRET_PREFIX, '')
          found = resolver.read(secret_key)
          resolved =
            if preview
              found ? "#{value} ✓" : "#{value} X"
            else
              found.to_s
            end
          env[key] = resolved
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
