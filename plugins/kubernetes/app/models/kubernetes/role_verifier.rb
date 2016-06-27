module Kubernetes
  class RoleVerifier
    DEPLOYISH = RoleConfigFile::DEPLOY_KINDS
    JOBS = RoleConfigFile::JOB_KINDS

    def initialize(role_definition)
      @errors = []
      @elements = load(role_definition)
    end

    def verify
      return @errors if @errors.any?
      verify_name
      verify_deployish
      verify_containers
      verify_no_mixing
      verify_job_container_name
      verify_job_restart_policy
      verify_service
      verify_numeric_limits
      verify_project_and_role_consistent
      @errors.presence
    end

    private

    def verify_name
      @errors << "Needs a metadata.name" unless map_attributes([:metadata, :name]).all?
    end

    def verify_deployish
      expected = DEPLOYISH + JOBS
      return if (map_attributes([:kind]) & expected).any?
      @errors << "Did not include supported kinds: #{expected.join(", ")}"
    end

    def verify_service
      return if map_attributes([:kind]).count('Service') <= 1
      @errors << "Can only have maximum of 1 Service"
    end

    # spec actually allows this, but blows up when used
    def verify_numeric_limits
      base = [:spec, :template, :spec, :containers, :resources, :limits, :cpu]
      types = map_attributes(base, array: :first).map(&:class)
      return if (types - [NilClass, String]).none?
      @errors << "Numeric cpu limits are not supported"
    end

    def load(role_definition)
      if role_definition.start_with?('{', '[')
        Array.wrap(JSON.load(role_definition))
      else
        YAML.load_stream(role_definition).compact
      end
    rescue
      @errors << "Unable to parse role definition"
      nil
    end

    def verify_project_and_role_consistent
      labels = @elements.flat_map do |resource|
        kind = resource['kind']

        label_paths =
          case kind
          when 'Service'
            [['spec', 'selector']]
          when *DEPLOYISH
            [
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
          path.inject(resource) { |r, k| r[k] || {} }.slice('project', 'role')
        end
      end

      labels = labels.uniq
      return if labels.size == 1 && labels.first.size == 2
      @errors << "Project and role labels must be consistent accross Deployment/DaemonSet/Service/Job"
    end

    def verify_containers
      expected = DEPLOYISH + JOBS
      deployish = @elements.select { |e| expected.include?(e['kind']) }
      containers = map_attributes([:spec, :template, :spec, :containers], elements: deployish)
      return if containers.all? { |c| c.is_a?(Array) && c.size >= 1 }
      @errors << "#{expected.join("/")} need at least 1 container"
    end

    def verify_no_mixing
      expected = DEPLOYISH + JOBS
      deployish = @elements.select { |e| expected.include?(e['kind']) }
      return if deployish.size == 1
      @errors << "Only 1 item of type #{expected.join('/')} is supported per role"
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
