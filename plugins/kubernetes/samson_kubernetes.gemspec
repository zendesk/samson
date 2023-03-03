# frozen_string_literal: true
Gem::Specification.new 'samson_kubernetes', '0.0.1' do |s|
  s.description = s.summary = 'Allow deploying projects using Kubernetes'
  s.authors = ['Jon Moter', 'Maciek Sufa', 'Sergio Nunes', 'Shane Hender']
  s.email = 'jmoter@zendesk.com'
  s.add_runtime_dependency 'kubeclient'
end
