# frozen_string_literal: true
module Kubernetes
  class RoleValidator
    # per https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set
    # not perfect since the actual rules are stricter
    VALID_LABEL_VALUE = /\A[a-zA-Z0-9]([-a-zA-Z0-9_.]*[a-zA-Z0-9])?\z/.freeze
    VALID_CONTAINER_NAME = /\A[a-zA-Z0-9]([-a-zA-Z0-9.]*[a-zA-Z0-9])?\z/.freeze # also used in js ... cannot use /i

    # for non-namespace deployments: names that should not be changed since they will break dependencies
    IMMUTABLE_NAME_KINDS = [
      'APIService', 'CustomResourceDefinition', 'ConfigMap', 'Role', 'ClusterRole', 'Namespace', 'PodSecurityPolicy',
      'ClusterRoleBinding'
    ].freeze

    # we either generate multiple names or allow custom names
    ALLOWED_DUPLICATE_KINDS = ((['Service'] + IMMUTABLE_NAME_KINDS)).freeze

    DATADOG_AD_REGEXP = %r{(?:service-discovery|ad)\.datadoghq\.com/([^.]+)\.}.freeze

    def initialize(elements, project:)
      @project = project
      @elements = elements.compact
    end

    def validate
      @errors = []
      return ["No content found"] if @elements.blank?
      return ["Only hashes supported"] unless @elements.all? { |e| e.is_a?(Hash) }
      validate_name
      validate_namespace
      validate_name_kinds_are_unique
      validate_single_primary_kind
      validate_api_version
      validate_containers_exist
      validate_container_name
      validate_container_resources
      validate_job_restart_policy
      validate_pod_disruption_budget
      validate_security_context
      validate_project_and_role_consistent
      validate_team_labels
      validate_not_matching_team
      validate_stateful_set_service_consistent
      validate_daemon_set_supported
      unless validate_annotations
        validate_prerequisites_kinds
        validate_prerequisites_consistency
        validate_datadog_annotations
      end
      validate_env_values
      validate_host_volume_paths
      @errors.presence
    end

    # @param [Array<Array<Hash>>] elements for a single deploy group, grouped by role
    def self.validate_groups(element_groups)
      return if element_groups.all?(&:empty?)

      errors = []

      # user tries to deploy the exact same resource multiple times from different roles
      element_groups.each do |elements|
        errors.concat elements.
          map { |e| "#{e[:kind]} #{e.dig(:metadata, :namespace)}.#{e.dig(:metadata, :name)} exists multiple times" }.
          group_by(&:itself).
          select { |_, v| v.size >= 2 }.
          keys
      end

      # role/project labels are used correctly
      unless element_groups.any? { |e| e.any? { |r| r.dig(:metadata, :annotations, :"samson/multi_project") } }
        element_groups.each do |es|
          roles = es.map { |r| r.dig(:metadata, :labels, :role) }.uniq
          if roles.size != 1 || roles == [nil]
            errors << "metadata.labels.role must be set and consistent in each config file"
          end
        end

        roles = element_groups.map(&:first).map { |r| r.dig(:metadata, :labels, :role) }
        if roles.uniq.size != element_groups.size
          errors << "metadata.labels.role must be set and different in each role"
        end

        projects = element_groups.flat_map { |e| e.map { |r| r.dig(:metadata, :labels, :project) } }.uniq
        errors << "metadata.labels.project must be consistent but found #{projects.inspect}" if projects.size != 1
      end

      raise Samson::Hooks::UserError, errors.join(", ") if errors.any?
    end

    def self.keep_name?(e)
      e.dig(:metadata, :annotations, :'samson/keep_name') == 'true'
    end

    private

    def validate_name
      @errors << "Needs a metadata.name" unless map_attributes([:metadata, :name]).all?
    end

    # not setting a namespace is safe to ignore, because template-filler overrides it with the configured namespace
    # and that either sets the namespace or is ignored for namespace-less resources
    def validate_namespace
      return unless namespace = @project&.kubernetes_namespace&.name

      namespaces = []
      @elements.each { |e| namespaces << e.dig(:metadata, :namespace) if e[:metadata].key?(:namespace) }
      namespaces.uniq!
      return if namespaces.empty? || namespaces == [namespace]

      @errors << "Only use configured namespace #{namespace.inspect}, not #{namespaces.inspect}"
    end

    # multiple pods in a single role will make validations misbehave (recommend they all have the same role etc)
    # also template filler won't know how to set images/resources
    def validate_single_primary_kind
      return if templates.size <= 1
      @errors << "Only use a maximum of 1 template with containers, found: #{templates.size}"
    end

    # template_filler.rb sets name for everything except for IMMUTABLE_NAME_KINDS, keep_name, and Service
    # we make sure users dont use the same name on the same kind twice, to avoid them overwriting each other
    # if they run in the default namespace
    def validate_name_kinds_are_unique
      # do not validate on global since we hope to be on namespace soon
      return if !@project || !@project.override_resource_names?

      # ignore services where we generate their names
      elements = @elements.reject { |e| !e[:kind] || (e[:kind] == "Service" && !self.class.keep_name?(e)) }

      # group by kind+name and to sure we have no duplicates
      groups = elements.group_by do |e|
        user_supplied = (ALLOWED_DUPLICATE_KINDS.include?(e.fetch(:kind)) || self.class.keep_name?(e))
        [e.fetch(:kind), e.dig(:metadata, :namespace), user_supplied ? e.dig(:metadata, :name) : "hardcoded"]
      end.values
      bad = groups.select { |group| group.size > 1 }
      return if bad.empty?

      bad_kinds = bad.map { |g| g.first[:kind] }
      @errors <<
        "Only use 1 per kind #{bad_kinds.join(", ")} in a role\n" \
        "To bypass: assign a namespace to the project, or set metadata.annotations.samson/keep_name=\"true\""
    end

    def validate_api_version
      @errors << "Needs apiVersion specified" if map_attributes([:apiVersion]).any?(&:nil?)
    end

    # validate datadog-specific annotations against
    # https://docs.datadoghq.com/agent/autodiscovery/integrations/?tab=kubernetes#configuration
    def validate_datadog_annotations
      templates.each do |template|
        annotations = template.dig(:metadata, :annotations) || {}
        containers = template.dig(:spec, :containers) || []
        dd_container_names = annotations.keys.map { |k| k[DATADOG_AD_REGEXP, 1] }.compact.uniq
        spec_container_names = containers.map { |c| c[:name] }.compact
        invalid = dd_container_names - spec_container_names

        unless invalid.empty?
          @errors << "Datadog annotation specified for non-existent container name: #{invalid.join(',')}"
        end
      end
    end

    def validate_security_context
      templates.each do |template|
        next unless template.dig(:spec, :securityContext, :readOnlyRootFilesystem)
        @errors << "securityContext.readOnlyRootFilesystem can only be set at the container level"
      end
    end

    def validate_project_and_role_consistent
      labels = @elements.flat_map do |resource|
        kind = resource[:kind]
        name = object_name(resource)
        label_paths = metadata_paths(resource).map { |p| p + [:labels] } +
          if resource.dig(:spec, :selector, :matchLabels) || resource[:kind] == "Deployment"
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
            @errors << "Missing #{wanted.join(' or ')} for #{kind} #{name}: #{path.join('.')}"
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

    def object_name(resource)
      meta = resource[:metadata]
      return "" unless meta
      name = meta[:name]
      namespace = meta[:namespace]
      return name unless namespace
      "#{namespace}/#{name}"
    end

    def validate_not_matching_team
      paths = [[:spec, :selector, :team], [:spec, :selector, :matchLabels, :team]]
      @elements.each do |element|
        if paths.any? { |p| element.dig(*p) }
          message = paths.map { |p| p.join(".") }.join(" or ")
          @errors << "Do not use #{message}, they can change and will break routing."
        end
      end
    end

    def validate_team_labels
      return unless ENV["KUBERNETES_ENFORCE_TEAMS"]
      @elements.each do |element|
        metadata_paths(element).map { |p| p + [:labels, :team] }.each do |path|
          @errors << "#{element[:kind]} #{path.join(".")} must be set" unless element.dig(*path)
        end
      end
    end

    def validate_stateful_set_service_consistent
      return unless service = @elements.detect { |t| t[:kind] == "Service" }
      return unless set = find_stateful_set
      return if set.dig(:spec, :serviceName) == service.dig(:metadata, :name)
      @errors << "Service metadata.name and StatefulSet spec.serviceName must be consistent"
    end

    def validate_daemon_set_supported
      return unless daemon_set = @elements.detect { |t| t[:kind] == "DaemonSet" }

      if daemon_set[:apiVersion] != "apps/v1"
        @errors << "set DaemonSet apiVersion to apps/v1"
        return
      end

      unless [nil, "RollingUpdate"].include? daemon_set.dig(:spec, :updateStrategy, :type)
        @errors << "set DaemonSet spec.updateStrategy.type to RollingUpdate"
        return
      end

      unless daemon_set.dig(:spec, :updateStrategy, :rollingUpdate, :maxUnavailable)
        @errors << "set DaemonSet spec.updateStrategy.rollingUpdate.maxUnavailable, the default of 1 is too slow" \
          " (pick something between '25%' and '100%')"
        nil
      end
    end

    def validate_containers_exist
      return if pod_containers.all? { |c| c.is_a?(Array) && c.any? }
      @errors << "All templates need spec.containers"
    end

    def validate_container_name
      names = (pod_containers + init_containers).flatten(1).map { |c| c[:name] }
      if names.any?(&:nil?)
        @errors << "Containers need a name"
      elsif bad = names.grep_v(VALID_CONTAINER_NAME).presence
        @errors << "Container name #{bad.join(", ")} did not match #{VALID_CONTAINER_NAME.source}"
      end
    end

    # keep in sync with TemplateFiller#set_resource_usage
    def validate_container_resources
      (pod_containers.map { |c| c[1..] || [] } + init_containers).flatten(1).each do |container|
        [
          [:resources, :requests, :cpu],
          [:resources, :requests, :memory],
          [:resources, :limits, :cpu],
          [:resources, :limits, :memory],
        ].each do |path|
          next if container.dig(*path)
          name = container[:name] || container[:image] || "unknown"
          @errors << "Container #{name} is missing #{path.join(".")}"
        end
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

      min = budget.dig(:spec, :minAvailable)
      max = budget.dig(:spec, :maxUnavailable)
      return if !min && !max

      @elements.each do |e|
        next unless replicas = e.dig(:spec, :replicas)
        next if min && percentage_available(min, replicas) < replicas
        next if max && percentage_available(max, replicas) > 0

        @errors <<
          "PodDisruptionBudget spec.minAvailable/spec.maxUnavailable " \
          "must leave at least 1 replica for termination, to avoid eviction deadlock"
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

    def percentage_available(num, total)
      if num.is_a?(Integer)
        num
      else
        (Float(num[/\d+/]) * total / 100).ceil # kubernetes rounds up
      end
    end

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
            break map_attributes(path[(i + 1)..], elements: el).flatten(1)
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
