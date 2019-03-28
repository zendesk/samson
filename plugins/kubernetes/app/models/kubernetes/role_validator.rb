# frozen_string_literal: true
module Kubernetes
  class RoleValidator
    # per https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set
    # not perfect since the actual rules are stricter
    VALID_LABEL_VALUE = /\A[a-zA-Z0-9]([-a-zA-Z0-9.]*[a-zA-Z0-9])?\z/.freeze # also used in js ... cannot use /i

    NAMESPACELESS_KINDS = [
      'APIService', 'ClusterRoleBinding', 'ClusterRole', 'CustomResourceDefinition', 'Namespace'
    ].freeze
    IMMUTABLE_NAME_KINDS = [
      'APIService', 'CustomResourceDefinition', 'ConfigMap', 'Role', 'ClusterRole', 'Namespace'
    ].freeze

    # we either generate multiple names or allow custom names
    ALLOWED_DUPLICATE_KINDS = ((['Service'] + IMMUTABLE_NAME_KINDS)).freeze

    def initialize(elements)
      @elements = elements.compact
    end

    def validate
      @errors = []
      return ["No content found"] if @elements.blank?
      return ["Only hashes supported"] unless @elements.all? { |e| e.is_a?(Hash) }
      validate_name
      validate_name_kinds_are_unique
      validate_namespace
      validate_single_primary_kind
      validate_api_version
      validate_containers
      validate_container_name
      validate_job_restart_policy
      validate_pod_disruption_budget
      validate_numeric_limits
      validate_project_and_role_consistent
      validate_team_labels
      validate_not_matching_team
      validate_stateful_set_service_consistent
      validate_stateful_set_restart_policy
      unless validate_annotations
        validate_prerequisites_kinds
        validate_prerequisites_consistency
      end
      validate_env_values
      validate_host_volume_paths
      @errors.presence
    end

    def self.validate_groups(element_groups)
      elements = element_groups.flatten(1)
      return if elements.empty?
      return if elements.any? { |r| r.dig(:metadata, :annotations, :"samson/multi_project") }

      errors = []

      element_groups.each do |element_group|
        roles = element_group.map { |r| r.dig(:metadata, :labels, :role) }.uniq
        if roles.size != 1 || roles == [nil]
          errors << "metadata.labels.role must be set and consistent in each config file"
        end
      end

      roles = element_groups.map(&:first).map { |r| r.dig(:metadata, :labels, :role) }
      errors << "metadata.labels.role must be set and unique" if roles.uniq.size != element_groups.size

      projects = elements.map { |r| r.dig(:metadata, :labels, :project) }.uniq
      errors << "metadata.labels.project must be consistent" if projects.size != 1

      raise Samson::Hooks::UserError, errors.join(", ") if errors.any?
    end

    def self.keep_name?(e)
      e.dig(:metadata, :annotations, :'samson/keep_name') == 'true'
    end

    private

    def validate_name
      @errors << "Needs a metadata.name" unless map_attributes([:metadata, :name]).all?
    end

    def validate_namespace
      elements = @elements.reject { |e| NAMESPACELESS_KINDS.include? e[:kind] }
      namespaces = map_attributes([:metadata, :namespace], elements: elements)
      @errors << "Namespaces need to be unique" if namespaces.uniq.size != 1
    end

    # multiple pods in a single role will make validations misbehave (recommend they all have the same role etc)
    # also template filler won't know how to set images/resources
    def validate_single_primary_kind
      return if templates.size <= 1
      @errors << "Only use a maximum of 1 template with containers, found: #{templates.size}"
    end

    # template_filler.rb sets name for everything except for IMMUTABLE_NAME_KINDS, keep_name, and Service
    # we make sure users dont use the same name on the same kind twice, to avoid them overwriting each other
    def validate_name_kinds_are_unique
      # ignore service if we generate their names
      elements = @elements.reject { |e| !e[:kind] || (e[:kind] == "Service" && !self.class.keep_name?(e)) }

      # group by kind+name and to sure we have no duplicates
      groups = elements.group_by do |e|
        user_supplied = (ALLOWED_DUPLICATE_KINDS.include?(e.fetch(:kind)) || self.class.keep_name?(e))
        [e.fetch(:kind), user_supplied ? e.dig(:metadata, :name) : "hardcoded"]
      end.values
      return if groups.all? { |group| group.size == 1 }

      @errors << "Only use a maximum of 1 of each kind in a role (except #{ALLOWED_DUPLICATE_KINDS.to_sentence})"
    end

    def validate_api_version
      @errors << "Needs apiVersion specified" if map_attributes([:apiVersion]).any?(&:nil?)
    end

    # spec actually allows this, but blows up when used
    def validate_numeric_limits
      [:requests, :limits].each do |scope|
        base = [:spec, :containers, :resources, scope, :cpu]
        types = map_attributes(base, elements: templates).flatten(1).map(&:class)
        next if (types - [NilClass, String]).none?
        @errors << "Numeric cpu resources are not supported"
      end
    end

    def validate_project_and_role_consistent
      labels = @elements.flat_map do |resource|
        kind = resource[:kind]

        label_paths = metadata_paths(resource).map { |p| p + [:labels] } +
          if resource.dig(:spec, :selector, :matchLabels)
            [[:spec, :selector, :matchLabels]]
          elsif resource.dig(:spec, :selector) && !allow_selector_cross_match?(resource)
            [[:spec, :selector]]
          else
            [] # ignore unknown / unsupported types
          end

        label_paths.map do |path|
          labels = resource.dig(*path) || {}

          # role and project from all used labels
          wanted = [:project, :role]
          required = labels.slice(*wanted)
          if required.size != 2
            @errors << "Missing #{wanted.join(' or ')} for #{kind} #{path.join('.')}"
          end

          # make sure we get sane values for labels or deploy will blow up
          labels.each do |k, v|
            prefix = "#{kind} #{path.join('.')}.#{k} is #{v.inspect}"

            if v.is_a?(String)
              unless v.match?(VALID_LABEL_VALUE)
                @errors << "#{prefix}, but must match #{VALID_LABEL_VALUE.inspect}"
              end
            else
              @errors << "#{prefix}, but must be a String"
            end
          end

          required
        end
      end

      return if labels.uniq.size <= 1
      @errors << "Project and role labels must be consistent across resources"
    end

    def validate_not_matching_team
      @elements.each do |element|
        if element.dig(:spec, :selector, :team) || element.dig(:spec, :selector, :matchLabels, :team)
          @errors << "Team names change, do not select or match on them"
        end
      end
    end

    def validate_team_labels
      return unless ENV["KUBERNETES_ENFORCE_TEAMS"]
      @elements.each do |element|
        metadata_paths(element).map { |p| p + [:labels, :team] }.each do |path|
          @errors << "#{path.join(".")} must be set" unless element.dig(*path)
        end
      end
    end

    def validate_stateful_set_service_consistent
      return unless service = @elements.detect { |t| t[:kind] == "Service" }
      return unless set = find_stateful_set
      return if set.dig(:spec, :serviceName) == service.dig(:metadata, :name)
      @errors << "Service metadata.name and StatefulSet spec.serviceName must be consistent"
    end

    def validate_stateful_set_restart_policy
      return unless set = find_stateful_set
      return if set.dig(:spec, :updateStrategy)
      @errors << "StatefulSet spec.updateStrategy must be set. " \
        "OnDelete will be supported soon but is brittle/rough, prefer RollingUpdate on kubernetes 1.7+."
    end

    def validate_containers
      return if pod_containers.all? { |c| c.is_a?(Array) && c.any? }
      @errors << "All templates need spec.containers"
    end

    def validate_container_name
      names = (pod_containers + init_containers).flatten(1).map { |c| c[:name] }
      if names.any?(&:nil?)
        @errors << "Containers need a name"
      elsif bad = names.grep_v(VALID_LABEL_VALUE).presence
        @errors << "Container name #{bad.join(", ")} did not match #{VALID_LABEL_VALUE.source}"
      end
    end

    def validate_job_restart_policy
      allowed = ['Never', 'OnFailure']
      [
        ["Job", [:spec, :template, :spec, :restartPolicy]],
        ["CronJob", [:spec, :jobTemplate, :spec, :template, :spec, :restartPolicy]]
      ].each do |kind, path|
        names = map_attributes(path, elements: @elements.select { |e| e[:kind] == kind })
        next if names - allowed == []
        @errors << "#{kind} #{path.join('.')} must be one of #{allowed.join('/')}"
      end
    end

    def validate_pod_disruption_budget
      return unless budget = @elements.detect { |e| e[:kind] == "PodDisruptionBudget" }
      return unless min = budget.dig(:spec, :minAvailable)
      @elements.each do |e|
        next unless replicas = e.dig(:spec, :replicas)
        next if min < replicas
        @errors << "PodDisruptionBudget spec.minAvailable must be lower than spec.replicas to avoid eviction deadlock"
      end
    end

    def validate_annotations
      annotations = @elements.flat_map { |e| metadata_paths(e).map { |path| e.dig(*(path + [:annotations])) }.compact }
      if annotations.any? { |a| !a.is_a?(Hash) }
        @errors << "Annotations must be a hash"
      else
        values = annotations.flat_map(&:values)
        bad = values.reject { |x| x.is_a?(String) }
        @errors << "Annotation values #{bad.join(', ')} must be strings." if bad.any?
      end
    end

    def validate_env_values
      path = [:spec, :containers, :env, :value]
      values = map_attributes(path, elements: templates).flatten(1).compact
      bad = values.reject { |x| x.is_a?(String) }
      @errors << "Env values #{bad.join(', ')} must be strings." if bad.any?
    end

    # samson waits for prerequisites to finish, so only resources that complete can be prerequisites
    def validate_prerequisites_kinds
      allowed = ["Job", "Pod"]
      return if map_attributes(RoleConfigFile::PREREQUISITE).compact.empty?
      return if (map_attributes([:kind]) & allowed).any? || templates.empty?

      @errors << "Prerequisites only support #{allowed.join(', ')}"
    end

    # only a whole role is supported to be a prerequisites, so prerequisites flag needs to be consistent
    def validate_prerequisites_consistency
      used = map_attributes(RoleConfigFile::PREREQUISITE).compact
      return if used.empty? || used.size == @elements.size && used.uniq.size <= 1

      @errors << "Prerequisite annotation must be used consistently across all resources of each role"
    end

    # comparing all directories with trailing / so we can use simple matching logic
    def validate_host_volume_paths
      return unless allowed = ENV['KUBERNETES_ALLOWED_VOLUME_HOST_PATHS'].presence
      allowed = allowed.split(",").map { |d| File.join(d, '') }
      used = map_attributes([:spec, :volumes, :hostPath, :path], elements: templates).
        flatten(1).compact.map { |d| File.join(d, '') }
      bad = used.select { |u| allowed.none? { |a| u.start_with?(a) } }
      @errors << "Only volume host paths #{allowed.join(", ")} are allowed, not #{bad.join(", ")}." if bad.any?
    end

    # helpers below

    def pod_containers
      map_attributes([:spec, :containers], elements: templates)
    end

    def init_containers
      templates.map { |t| (t.dig(:metadata, :annotations) || {}).is_a?(Hash) ? Api::Pod.init_containers(t) : [] }
    end

    def find_stateful_set
      @elements.detect { |t| t[:kind] == "StatefulSet" }
    end

    def templates(elements = @elements)
      elements.flat_map { |e| RoleConfigFile.templates(e) }
    end

    def metadata_paths(e)
      [[:metadata]] + RoleConfigFile.template_keys(e).flat_map do |k|
        template = e.dig_fetch(:spec, k)
        metadata_paths(template).map { |p| [:spec, k] + p }
      end
    end

    def map_attributes(path, elements: @elements)
      elements.map do |e|
        path.each_with_index.inject(e) do |el, (p, i)|
          el = el[p]
          if el.is_a?(Array)
            break map_attributes(path[(i + 1)..-1], elements: el).flatten(1)
          else
            el || break
          end
        end
      end
    end

    def allow_selector_cross_match?(resource)
      resource[:kind] == "Gateway" ||
        resource.dig(:metadata, :annotations, :"samson/service_selector_across_roles") == "true"
    end
  end
end
