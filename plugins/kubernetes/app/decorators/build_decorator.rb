Build.class_eval do
  has_many :kubernetes_releases, class_name: 'Kubernetes::Release'

  def project_name
    @project_name ||= project.name_for_label
  end
end
