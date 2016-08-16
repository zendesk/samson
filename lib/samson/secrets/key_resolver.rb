module Samson
  module Secrets
    class KeyResolver
      def initialize(project, deploy_groups)
        @project = project
        @deploy_groups = deploy_groups
        @errors = []
      end

      # expands a key by finding the most specific value for it
      # bar -> production/my_project/pod100/bar
      def expand!(secret_key)
        key = secret_key.split('/', 2).last

        # build a list of all possible ids
        possible_ids = possible_secret_key_parts.map do |id|
          SecretStorage.generate_secret_key(id.merge(key: key))
        end

        # use the value of the first id that exists
        all_found = SecretStorage.read_multi(possible_ids)

        if found = possible_ids.detect { |id| all_found[id] }
          secret_key.replace(found)
        else
          @errors << "#{secret_key} (tried: #{possible_ids.join(', ')})"
          nil
        end
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
