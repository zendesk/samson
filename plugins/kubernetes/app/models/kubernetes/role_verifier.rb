module Kubernetes
  class RoleVerifier
    DEPLOYISH = RoleConfigFile::DEPLOY_KINDS
    JOBS = RoleConfigFile::JOB_KINDS
    VALID_LABEL = /\A[a-z0-9]([-a-z0-9]*[a-z0-9])?\z/

    SUPPORTED_KINDS = [
      ['Deployment'],
      ['DaemonSet'],
      ['Deployment', 'Service'],
      ['Job']
    ].freeze

    def initialize(elements)
      @errors = []
      @elements = elements.compact
    end

    def verify
      return @errors if @errors.any?
      return ["No content found"] if @elements.blank?
      verify_name
      verify_kinds
      verify_containers
      verify_job_container_name
      verify_job_restart_policy
      verify_numeric_limits
      verify_project_and_role_consistent
      @errors.presence
    end

    private

    def verify_name
      @errors << "Needs a metadata.name" unless map_attributes([:metadata, :name]).all?
    end

    def verify_kinds
      kinds = map_attributes([:kind]).sort
      return if SUPPORTED_KINDS.include?(kinds)
      supported = SUPPORTED_KINDS.map { |c| c.join(' + ') }.join(', ')
      @errors << "Unsupported combination of kinds: #{kinds.join(' + ')}, supported combinations are: #{supported}"
    end

    # spec actually allows this, but blows up when used
    def verify_numeric_limits
      base = [:spec, :template, :spec, :containers, :resources, :limits, :cpu]
      types = map_attributes(base, array: :first).map(&:class)
      return if (types - [NilClass, String]).none?
      @errors << "Numeric cpu limits are not supported"
    end

    def verify_project_and_role_consistent
      labels = @elements.flat_map do |resource|
        kind = resource['kind']

        label_paths =
          case kind
          when 'Service'
            [
              ['metadata', 'labels'],
              ['spec', 'selector']
            ]
          when *DEPLOYISH
            [
              ['metadata', 'labels'],
              ['spec', 'template', 'metadata', 'labels'],
              ['spec', 'selector', 'matchLabels'],
            ]
          when *JOBS
            [
              ['metadata', 'labels'],
              ['spec', 'template', 'metadata', 'labels']
            ]
          else
            [] # ignore unknown / unsupported types
          end

        label_paths.map do |path|
          labels = path.inject(resource) { |r, k| r[k] || {} }

          # role and project from all used labels
          required = labels.slice('project', 'role')
          if required.size != 2
            @errors << "Missing label or role for #{kind} #{path.join('.')}"
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

      return if labels.uniq.size == 1
      @errors << "Project and role labels must be consistent across Deployment/DaemonSet/Service/Job"
    end

    def verify_containers
      expected = DEPLOYISH + JOBS
      deployish = @elements.select { |e| expected.include?(e['kind']) }
      containers = map_attributes([:spec, :template, :spec, :containers], elements: deployish)
      return if containers.all? { |c| c.is_a?(Array) && c.size >= 1 }
      @errors << "#{expected.join("/")} need at least 1 container"
    end

    # job needs a name since we atm do not enforce it's uniqueness like we do for service
    def verify_job_container_name
      names = map_attributes([:spec, :template, :spec, :containers, :name], elements: jobs, array: :first)
      return if names.all?
      @errors << "Job containers need a name"
    end

    def verify_job_restart_policy
      allowed = ['Never', 'OnFailure']
      path = [:spec, :template, :spec, :restartPolicy]
      names = map_attributes(path, elements: jobs)
      return if names - allowed == []
      @errors << "Job #{path.join('.')} must be one of #{allowed.join('/')}"
    end

    def jobs
      @elements.select { |e| JOBS.include?(e['kind']) }
    end

    def map_attributes(path, elements: @elements, array: :all)
      elements.map do |e|
        path.inject(e) do |e, p|
          e = e[p.to_s]
          e = Array.wrap(e).first if array == :first
          e || break
        end
      end
    end
  end
end
