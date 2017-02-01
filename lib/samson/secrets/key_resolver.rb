# frozen_string_literal: true

module Samson
  module Secrets
    class KeyResolver
      WILDCARD = '*'

      def initialize(project, deploy_groups)
        @project = project
        @deploy_groups = deploy_groups
        @errors = []
      end

      # expands a key by finding the most specific value for it
      # bar -> production/my_project/pod100/bar
      def expand(env_name, secret_key)
        env_name = env_name.to_s
        if env_name.end_with?(WILDCARD) ^ secret_key.end_with?(WILDCARD)
          @errors << "#{env_name} and #{secret_key} need to both end with #{WILDCARD} or not include them"
          return []
        end

        # build a list of all possible ids
        possible_ids = possible_secret_key_parts.map do |id|
          SecretStorage.generate_secret_key(id.merge(key: secret_key))
        end

        found = if secret_key.end_with?(WILDCARD)
          expand_wildcard_keys(env_name, secret_key, possible_ids)
        else
          expand_simple_key(env_name, possible_ids)
        end

        if found.empty?
          @errors << "#{secret_key} (tried: #{possible_ids.join(', ')})"
          return []
        end

        found
      end

      def read(key)
        return unless full_key = expand('unused-param', key).first&.last
        SecretStorage.read_multi([full_key], include_value: true).values.first&.fetch(:value) # read key without raising
      end

      # raises all errors at once for faster debugging
      def verify!
        if @errors.any?
          raise(
            Samson::Hooks::UserError,
            "Failed to resolve secret keys:\n\t#{@errors.join("\n\t")}"
          )
        end
      end

      private

      # find the first id that exists, preserving priority in possible_ids
      def expand_simple_key(env_name, possible_ids)
        if found = (possible_ids & SecretStorage.keys).first
          [[env_name, found]]
        else
          []
        end
      end

      # FOO_* with foo_* -> [[FOO_BAR, a/a/a/foo_bar], [FOO_BAZ, a/a/a/foo_baz]]
      def expand_wildcard_keys(env_name, secret_key, possible_ids)
        # look through all keys to check which ones match
        all = SecretStorage.keys
        matched = possible_ids.flat_map do |id|
          all.select { |a| a.start_with?(id.delete('*')) }
        end

        # pick the most specific id per key, they are already sorted ... [a/b/c/d, a/a/a/d] -> [a/b/c/d]
        matched.uniq! { |id| SecretStorage.parse_secret_key(id).fetch(:key) }

        # expand env name to match the expanded key
        # env FOO_* with key d_* finds id a/b/c/d_bar and results in [FOO_BAR, a/b/c/d_bar]
        matched.map! do |id|
          expanded = SecretStorage.parse_secret_key(id).fetch(:key)
          expanded.slice!(0, secret_key.size - 1)
          [env_name.delete('*') + expanded.upcase, id]
        end

        matched
      end

      def possible_secret_key_parts
        @possible_secret_key_parts ||= begin
          environments = @deploy_groups.map(&:environment).uniq

          # build list of allowed key parts
          environment_permalinks = ['global']
          project_permalinks = ['global']
          deploy_group_permalinks = ['global']

          environment_permalinks.concat(environments.map(&:permalink)) if environments.size == 1
          project_permalinks << @project.permalink if @project
          deploy_group_permalinks.concat(@deploy_groups.map(&:permalink)) if @deploy_groups.size == 1

          # build a list of all key part combinations, sorted by most specific
          deploy_group_permalinks.reverse_each.flat_map do |d|
            project_permalinks.reverse_each.flat_map do |p|
              environment_permalinks.reverse_each.map do |e|
                {
                  deploy_group_permalink: d,
                  project_permalink: p,
                  environment_permalink: e,
                }
              end
            end
          end
        end
      end
    end
  end
end
