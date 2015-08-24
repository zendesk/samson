Project.class_eval do
  has_many :kubernetes_releases, through: :builds
  has_many :roles, class_name: 'ProjectRole'
end
