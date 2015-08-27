Build.class_eval do

  has_many :kubernetes_releases
  attr_writer :project_name, :container_port
  attr_accessor :env

  def project_name
    @project_name ||= project.name.parameterize('-')
  end

  def env_for(deploy_group)
    EnvironmentVariable.env(project, deploy_group)
  end
end
