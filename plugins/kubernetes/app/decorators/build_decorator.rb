Build.class_eval do

  has_many :kubernetes_releases

  def project_name
    @project_name ||= project.name.parameterize('-')
  end
end
