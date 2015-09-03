Project.class_eval do
  has_many :kubernetes_release_groups, through: :builds, class_name: 'Kubernetes::ReleaseGroup'
  has_many :roles, class_name: 'Kubernetes::Role'
end
