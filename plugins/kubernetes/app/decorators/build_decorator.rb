Build.class_eval do

  has_many :kubernetes_release_groups, class_name: 'Kubernetes::ReleaseGroup'

  def project_name
    @project_name ||= project.name.parameterize('-')
  end
end
