Project.class_eval do
  has_many :kubernetes_releases, class_name: 'Kubernetes::Release'
  has_many :kubernetes_roles, class_name: 'Kubernetes::Role', dependent: :destroy
  has_many :kubernetes_deploy_group_roles, class_name: 'Kubernetes::DeployGroupRole'

  def name_for_label
    name.parameterize('-')
  end
end
