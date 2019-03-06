# frozen_string_literal: true
Build.class_eval do
  has_many :kubernetes_releases, class_name: 'Kubernetes::Release', dependent: nil
end
