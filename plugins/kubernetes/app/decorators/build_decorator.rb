Build.class_eval do

  has_many :kubernetes_release_groups, class_name: 'Kubernetes::ReleaseGroup'
  attr_writer :project_name
  attr_accessor :env

  def project_name
    @project_name ||= project.name.parameterize('-')
  end

  def env_for(deploy_group)
    EnvironmentVariable.env(project, deploy_group)
  end
end
