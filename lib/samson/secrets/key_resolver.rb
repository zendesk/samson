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
        return [] unless validate_wildcard(env_name, secret_key)

        possible_ids, forbidden_ids = partition_possible_ids(secret_key)

        found = find_keys(secret_key, env_name, possible_ids)
        found_but_forbidden = find_keys(secret_key, env_name, forbidden_ids).map(&:last)

        if found.empty?
          @errors << error_message(secret_key, possible_ids, found_but_forbidden)
          return []
        end

        found
      end

      # expand a single key and return full path if present
      def expand_key(key)
        expand('unused-param', key).first&.last
      end

      def read(key)
        return unless full_key = expand_key(key)
        Samson::Secrets::Manager.read_multi([full_key], include_value: true).
          values.first&.fetch(:value) # read key without raising
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

      def resolved_attribute(attribute_value)
        if key = attribute_value.to_s.dup.sub!(TerminalExecutor::SECRET_PREFIX, "")
          read(key)
        else
          attribute_value
        end
      end

      private

      # cache since we use this for every secret
      def ids
        @ids ||= Samson::Secrets::Manager.ids
      end

      def find_keys(secret_key, env_name, id_list)
        if secret_key.end_with?(WILDCARD)
          expand_wildcard_keys(env_name, secret_key, id_list)
        else
          expand_simple_key(env_name, id_list)
        end
      end

      # sorts possible ids for a secret into allowed and forbidden lists based on secret sharing grants
      def partition_possible_ids(secret_key)
        possible_secret_id_parts.each_with_object([[], []]) do |id_parts, (possible, forbidden)|
          id_parts = id_parts.merge(key: secret_key)
          id = Samson::Secrets::Manager.generate_id(id_parts)
          unless deprecated?(id)
            (key_granted?(id_parts) ? possible : forbidden) << id
          end
        end
      end

      def error_message(secret_key, possible_ids, forbidden_ids)
        if forbidden_ids.any?
          ignored_error = "(ignored: global secrets #{forbidden_ids.join(', ')} add a secret sharing grant to use them)"
        end

        <<~TEXT.strip
          #{secret_key}
            (tried: #{possible_ids.join(', ')})
            #{ignored_error}
        TEXT
      end

      # local cache so we do not have to re-fetch cache on every resolve
      def deprecated?(id)
        @deprecated_ids ||= Samson::Secrets::Manager.lookup_cache.each_with_object([]) do |(id, secret_stub), all|
          all << id if secret_stub.fetch(:deprecated_at)
        end
        @deprecated_ids.include?(id)
      end

      def validate_wildcard(env_name, secret_key)
        return true unless env_name.end_with?(WILDCARD) ^ secret_key.end_with?(WILDCARD)
        @errors << "#{env_name} and #{secret_key} need to both end with #{WILDCARD} or not include them"
        false
      end

      # find the first id that exists, preserving priority in possible_ids
      def expand_simple_key(env_name, possible_ids)
        if found = (possible_ids & ids).first
          [[env_name, found]]
        else
          []
        end
      end

      # FOO_* with foo_* -> [[FOO_BAR, a/a/a/foo_bar], [FOO_BAZ, a/a/a/foo_baz]]
      def expand_wildcard_keys(env_name, secret_key, possible_ids)
        # look through all keys to check which ones match
        matched = possible_ids.flat_map do |id|
          ids.select { |a| a.start_with?(id.delete('*')) }
        end

        # pick the most specific id per key, they are already sorted ... [a/b/c/d, a/a/a/d] -> [a/b/c/d]
        matched.uniq! { |id| Samson::Secrets::Manager.parse_id(id).fetch(:key) }

        # expand env name to match the expanded key
        # env FOO_* with key d_* finds id a/b/c/d_bar and results in [FOO_BAR, a/b/c/d_bar]
        matched.map! do |id|
          expanded = Samson::Secrets::Manager.parse_id(id).fetch(:key)
          expanded.slice!(0, secret_key.size - 1)
          [env_name.delete('*') + expanded.upcase, id]
        end

        matched
      end

      def key_granted?(key_parts)
        if Samson::Secrets::Manager.sharing_grants? && key_parts.fetch(:project_permalink) == "global"
          @shared_keys ||= @project.secret_sharing_grants.map(&:key)
          @shared_keys.include?(key_parts.fetch(:key))
        else
          true
        end
      end

      def possible_secret_id_parts
        @possible_secret_id_parts ||= begin
          environments = @deploy_groups.map(&:environment).uniq

          # build list of allowed key parts
          environment_permalinks = ['global']
          project_permalinks = ['global']
          deploy_group_permalinks = ['global']

          environment_permalinks.concat(environments.map(&:permalink)) if environments.size == 1
          project_permalinks << @project.permalink
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
