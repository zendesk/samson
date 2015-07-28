Project.class_eval do
  has_many :kubernetes_releases, through: :builds
end
