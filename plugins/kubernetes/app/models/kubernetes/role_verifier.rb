# frozen_string_literal: true
module Kubernetes
  class RoleVerifier
    VALID_LABEL = /\A[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?\z/ # also used in js ... cannot use /i
    IGNORED = ['ConfigMap', 'HorizontalPodAutoscaler'].freeze
    SUPPORTED_KINDS = [
      ['Deployment'],
      ['DaemonSet'],
      ['Deployment', 'Service'],
      ['Service', 'StatefulSet'],
      ['Job'],
      ['Pod'],
    ].freeze

    def initialize(elements, project)
      @errors = []
      @elements = elements.compact
      @project = project
    end

    def verify
      return @errors if @errors.any?
      return ["No content found"] if @elements.blank?
      return ["Only hashes supported"] unless @elements.all? { |e| e.is_a?(Hash) }
      verify_name
      verify_namespace
      verify_kinds
      verify_containers
      verify_container_name
      verify_job_restart_policy
      verify_numeric_limits
      verify_project_and_role_consistent
      verify_stateful_set_service_consistent
      verify_stateful_set_restart_policy
      verify_annotations || verify_prerequisites
      verify_env_values
      verify_host_volume_paths
      verify_readonly
      @errors.presence
    end

    def self.verify_group(elements)
      return if elements.empty?
      return if elements.any? { |r| r.dig(:metadata, :annotations, :"samson/multi_project") }

      errors = []

      roles = elements.map { |r| r.dig(:metadata, :labels, :role) }.compact
      errors << "metadata.labels.role must be set and unique" if roles.uniq.size != elements.size

      projects = elements.map { |r| r.dig(:metadata, :labels, :project) }.uniq
      errors << "metadata.labels.project must be consistent" if projects.size != 1

      raise Samson::Hooks::UserError, errors.join(", ") if errors.any?
    end

    private

    def verify_name
      @errors << "Needs a metadata.name" unless map_attributes([:metadata, :name]).all?
    end

    def verify_namespace
      @errors << "Namespaces need to be unique" if map_attributes([:metadata, :namespace]).uniq.size != 1
    end

    def verify_kinds
      kinds = map_attributes([:kind])
      IGNORED.each { |k| kinds.delete k }
      uniq_element!(kinds, 'Service') # ignore multiple services
      kinds.sort_by!(&:to_s)

      return if SUPPORTED_KINDS.include?(kinds)
      supported = SUPPORTED_KINDS.map { |c| c.join(' + ') }.join(', ')
      @errors << "Unsupported combination of kinds: #{kinds.join(' + ')}" \
        ", supported combinations are: #{supported} and #{IGNORED.join(", ")}"
    end

    # [1,2,3,1,4] -> [2,3,4,1]
    def uniq_element!(array, element)
      if array.count(element) > 1
        array.delete(element)
        array << element
      end
    end

    # spec actually allows this, but blows up when used
    def verify_numeric_limits
      [:requests, :limits].each do |scope|
        base = [:spec, :containers, :resources, scope, :cpu]
        types = map_attributes(base, elements: templates).flatten(1).map(&:class)
        next if (types - [NilClass, String]).none?
        @errors << "Numeric cpu resources are not supported"
      end
    end

    def verify_project_and_role_consistent
      labels = @elements.flat_map do |resource|
        kind = resource[:kind]

        label_paths =
          case kind
          when 'Service'
            [
              [:metadata, :labels],
              [:spec, :selector]
            ]
          when *RoleConfigFile::DEPLOY_KINDS
            [
              [:metadata, :labels],
              [:spec, :template, :metadata, :labels],
              [:spec, :selector, :matchLabels],
            ]
          when *RoleConfigFile::JOB_KINDS
            [
              [:metadata, :labels],
              [:spec, :template, :metadata, :labels]
            ]
          else # when adding new keep consistent with error message below
            [] # ignore unknown / unsupported types
          end

        label_paths.map do |path|
          labels = path.inject(resource) { |r, k| r[k] || {} }

          # role and project from all used labels
          wanted = [:project, :role]
          required = labels.slice(*wanted)
          if required.size != 2
            @errors << "Missing #{wanted.join(' or ')} for #{kind} #{path.join('.')}"
          end

          # make sure we get sane values for labels or deploy will blow up
          labels.each do |k, v|
            if v.is_a?(String)
              @errors << "#{kind} #{path.join('.')}.#{k} must match #{VALID_LABEL.inspect}" unless v =~ VALID_LABEL
            else
              @errors << "#{kind} #{path.join('.')}.#{k} must be a String"
            end
          end

          required
        end
      end

      return if labels.uniq.size <= 1
      @errors << "Project and role labels must be consistent across Deployment/DaemonSet/Service/Job"
    end

    def verify_stateful_set_service_consistent
      return unless service = @elements.detect { |t| t[:kind] == "Service" }
      return unless set = find_stateful_set
      return if set.dig(:spec, :serviceName) == service.dig(:metadata, :name)
      @errors << "Service metadata.name and StatefulSet spec.serviceName must be consistent"
    end

    def verify_stateful_set_restart_policy
      return unless set = find_stateful_set
      return if set.dig(:spec, :updateStrategy)
      @errors << "StatefulSet spec.updateStrategy must be set. " \
        "OnDelete will be supported soon but is brittle/rough, prefer RollingUpdate on kubernetes 1.7+."
    end

    def find_stateful_set
      @elements.detect { |t| t[:kind] == "StatefulSet" }
    end

    def verify_containers
      primary_kinds = RoleConfigFile::PRIMARY_KINDS
      containered = templates.select { |t| primary_kinds.include?(t[:kind]) }
      containers = map_attributes([:spec, :containers], elements: containered)
      return if containers.all? { |c| c.is_a?(Array) && c.size >= 1 }
      @errors << "#{primary_kinds.join("/")} need at least 1 container"
    end

    def verify_container_name
      names = map_attributes([:spec, :containers], elements: templates).compact.flatten(1).map { |c| c[:name] }
      if names.any?(&:nil?)
        @errors << "Containers need a name"
      elsif bad = names.grep_v(VALID_LABEL).presence
        @errors << "Container name #{bad.join(", ")} did not match #{VALID_LABEL.source}"
      end
    end

    def verify_job_restart_policy
      allowed = ['Never', 'OnFailure']
      path = [:spec, :template, :spec, :restartPolicy]
      names = map_attributes(path, elements: jobs)
      return if names - allowed == []
      @errors << "Job #{path.join('.')} must be one of #{allowed.join('/')}"
    end

    def verify_annotations
      path = [:metadata, :annotations]
      annotations = (map_attributes(path, elements: templates) + map_attributes(path)).compact
      if annotations.any? { |a| !a.is_a?(Hash) }
        @errors << "Annotations must be a hash"
      else
        values = annotations.flat_map(&:values)
        bad = values.reject { |x| x.is_a?(String) }
        @errors << "Annotation values #{bad.join(', ')} must be strings." if bad.any?
      end
    end

    def verify_env_values
      path = [:spec, :containers, :env, :value]
      values = map_attributes(path, elements: templates).flatten(1).compact
      bad = values.reject { |x| x.is_a?(String) }
      @errors << "Env values #{bad.join(', ')} must be strings." if bad.any?
    end

    def verify_prerequisites
      allowed = ["Job", "Pod"]
      bad = templates.any? do |t|
        t.dig(*RoleConfigFile::PREREQUISITE) && !allowed.include?(t[:kind])
      end
      @errors << "Only elements with type #{allowed.join(", ")} can be prerequisites." if bad
    end

    # comparing all directories with trailing / so we can use simple matching logic
    def verify_host_volume_paths
      return unless allowed = ENV['KUBERNETES_ALLOWED_VOLUME_HOST_PATHS'].presence
      allowed = allowed.split(",").map { |d| File.join(d, '') }
      used = map_attributes([:spec, :volumes, :hostPath, :path], elements: templates).
        flatten(1).compact.map { |d| File.join(d, '') }
      bad = used.select { |u| allowed.none? { |a| u.start_with?(a) } }
      @errors << "Only volume host paths #{allowed.join(", ")} are allowed, not #{bad.join(", ")}." if bad.any?
    end

    def verify_readonly
      path = [:spec, :containers, :securityContext, :readOnlyRootFilesystem]
      return if map_attributes(path, elements: templates).all? || @project.allow_writing_to_root_filesystem
      @errors << "Set `securityContext: readOnlyRootFilesystem: true` for all containers or " \
        "enable `Allow writing to root filesystem` in project settings."
    end

    # helpers below

    def jobs
      @elements.select { |e| RoleConfigFile::JOB_KINDS.include?(e[:kind]) }
    end

    def templates
      @elements.map do |e|
        kind = e[:kind]
        if kind != 'Pod'
          e = e.dig(:spec, :template) || {}
          e[:kind] = kind
        end
        e
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
  end
end
