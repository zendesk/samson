module Kubernetes
  class RoleVerifier
    DEPLOYISH = ['Deployment', 'DaemonSet'].freeze

    def initialize(role_definition)
      @errors = []
      @elements = load(role_definition)
    end

    def verify
      return @errors if @errors.any?
      verify_name
      verify_deployish
      verify_containers
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
      expected = ['Deployment', 'DaemonSet']
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
        YAML.load_stream(role_definition)
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
          else
            [] # ignore unknown / unsupported types
          end

        label_paths.map do |path|
          path.inject(resource) { |r, k| r[k] || {} }.slice('project', 'role')
        end
      end

      labels = labels.uniq
      return if labels.size == 1 && labels.first.size == 2
      @errors << "Project and role labels must be consistent accross Deployment/DaemonSet/Service"
    end

    def verify_containers
      deployish = @elements.select { |e| DEPLOYISH.include?(e['kind']) }
      containers = map_attributes([:spec, :template, :spec, :containers], elements: deployish)
      return if containers.all? { |c| c.is_a?(Array) && c.size >= 1 }
      @errors << "Deployments and DaemonSets need at least 1 container"
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
