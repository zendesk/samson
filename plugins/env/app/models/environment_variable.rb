# frozen_string_literal: true
require 'validates_lengths_from_database'

class EnvironmentVariable < ActiveRecord::Base
  FAILED_LOOKUP_MARK = ' X' # SpaceX
  PARENT_PRIORITY = ["Deploy", "Stage", "Project", "EnvironmentVariableGroup"].freeze
  EXTERNAL_VARIABLE_CACHE_DURATION = 5.minutes

  include GroupScope
  extend Inlinable
  audited

  belongs_to :parent, polymorphic: true # Resource they are set on

  validates :name, presence: true
  validates :parent_type, inclusion: PARENT_PRIORITY

  include ValidatesLengthsFromDatabase
  validates_lengths_from_database only: :value

  allow_inline delegate :name, to: :parent, prefix: true, allow_nil: true
  allow_inline delegate :name, to: :scope, prefix: true, allow_nil: true

  class << self
    # preview parameter can be used to not raise an error,
    # but return a value with a helpful message
    # also used by an external plugin
    def env(deploy, deploy_group, resolve_secrets:, project_specific: nil, base: {})
      env = base.dup

      if deploy_group
        env.merge! env_vars_from_external_groups(deploy.project, deploy_group)
      end

      env.merge! env_vars_from_db(deploy, deploy_group, project_specific: project_specific)

      # TODO: these should be handled outside of the env plugin so other plugins can get their env var resolved too
      resolve_dollar_variables!(env)
      resolve_secrets(deploy.project, deploy_group, env, preview: resolve_secrets == :preview) if resolve_secrets

      env
    end

    # scopes is given as argument since it needs to be cached
    def sort_by_scopes(variables, scopes)
      variables.sort_by { |x| [x.name, scopes.index { |_, s| s == x.scope_type_and_id } || 999] }
    end

    # env_scopes is given as argument since it needs to be cached
    def serialize(variables, env_scopes)
      sorted = EnvironmentVariable.sort_by_scopes(variables, env_scopes)
      sorted.map do |var|
        "#{var.name}=#{var.value.inspect} # #{var.scope&.name || "All"}"
      end.join("\n")
    end

    private

    def env_vars_from_db(deploy, deploy_group, **args)
      variables =
        deploy.environment_variables +
        (deploy.stage&.environment_variables || []) +
        deploy.project.nested_environment_variables(**args)
      variables.sort_by!(&:priority)
      variables.each_with_object({}) do |ev, all|
        all[ev.name] = ev.value.dup if !all[ev.name] && ev.matches_scope?(deploy_group)
      end
    end

    def env_vars_from_external_groups(project, deploy_group)
      external_groups = project.external_environment_variable_groups

      external_groups += (project.environment_variable_groups.select(&:external_url?).map do |env_group|
        ExternalEnvironmentVariableGroup.new(url: env_group.external_url)
      end)

      Samson::Parallelizer.map(external_groups) do |group|
        all_groups = Rails.cache.fetch("env-#{group.url}-read", expires_in: EXTERNAL_VARIABLE_CACHE_DURATION) do
          group.read
        end
        all_groups[deploy_group.permalink] || all_groups["*"]
      end.compact.inject({}, :merge!)
    rescue StandardError => e
      raise Samson::Hooks::UserError, "Error reading env vars from external env-groups: #{e.message}"
    end

    def resolve_dollar_variables!(env)
      env.each_value do |value|
        3.times do
          break unless value.gsub!(/\$\{(\w+)\}|\$(\w+)/) { |original| env[$1 || $2] || original }
        end
      end
    end

    def resolve_secrets(project, deploy_group, env, preview:)
      resolver = Samson::Secrets::KeyResolver.new(project, Array(deploy_group))
      env.each do |key, value|
        next unless secret_key = value.dup.sub!(/^#{Regexp.escape TerminalExecutor::SECRET_PREFIX}/, '')
        found = resolver.read(secret_key)
        resolved =
          if preview
            path = resolver.expand_key(secret_key)
            path ? "#{TerminalExecutor::SECRET_PREFIX}#{path}" : "#{value}#{FAILED_LOOKUP_MARK}"
          else
            found.to_s
          end
        env[key] = resolved
      end
      resolver.verify! unless preview
    end
  end

  def priority
    [PARENT_PRIORITY.index(parent_type) || 999, super]
  end

  private

  # callback for audited
  def auditing_enabled
    parent_type != "Deploy" && super
  end
end
