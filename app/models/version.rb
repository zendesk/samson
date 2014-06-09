class Version
  attr_reader :data

  def initialize(versioning_schema, version_str = "")
    @versioning_schema = versioning_schema
    @data = build_version_data(version_str)
  end

  def component_keys
    @component_keys ||= @versioning_schema.scan(/{(\w+)}/).flatten
  end

  def default_bump_component
    component_keys.last
  end

  def bump(bump_type = 'default')
    if (bump_type == 'default')
      bump_component(default_bump_component)
    else
      bump_component(bump_type)
    end

    value
  end

  def value
    delimiters.zip(component_values).flatten.join("")
  end

  def to_s
    value
  end

  private

  def delimiters
    @delimiters ||= @versioning_schema.scan(/([\w|\-|\.]+){\w+}/).flatten
  end

  def component_values
    [].tap do |values|
      component_keys.each do |component|
        values << @data[component]
      end
    end
  end

  def build_version_data(version_str)
    if (version_str.length > 0)
      parse_version_data(version_str)
    else
      build_initial_version
    end
  end

  def parse_version_data(version_str)
    component_keys.zip(parse_component_values(version_str)).to_h
  end

  def parse_component_values(version_str)
    version_str.scan(/\d+/).map(&:to_i)
  end

  def build_initial_version
    component_values = [0] * (component_keys.length - 1) + [1]
    component_keys.zip(component_values).to_h
  end

  def bump_component(component)
    @data[component] += 1
  end
end
