Project.class_eval do
  has_many :kubernetes_releases, through: :builds, class_name: 'Kubernetes::Release'
  has_many :roles, class_name: 'Kubernetes::Role'
end
