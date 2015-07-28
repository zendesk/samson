Build.class_eval do

  has_many :kubernetes_releases
  attr_writer :project_name, :container_port
  attr_accessor :env

  def pod_name
    "#{project_name}-rc"
  end

  def project_name
    @project_name ||= project.name.parameterize('-')
  end

  def controller_name
    "#{project_name}-ctrl"
  end

  def service_name
    project_name
  end

  def container_port
    4242
  end

  def service_port
    8008
  end

  def env_for(deploy_group)
    EnvironmentVariable.env(project, deploy_group)
  end

  def missing_env_vars_for(deploy_group)
    required_env_vars - env_for(deploy_group).keys
  end

  def manifest
    @manifest ||= begin
      contents = file_from_repo('manifest.json')
      contents ? JSON.parse(contents).with_indifferent_access : {}
    end
  end

  def required_env_vars
    (manifest[:settings] || {}).each_with_object([]) do |(k,v),arr|
      arr << k if v.fetch(:required, true)
    end
  end

  def manifest_roles
    manifest.fetch(:roles, {})
  end
end
