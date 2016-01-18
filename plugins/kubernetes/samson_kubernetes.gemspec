Gem::Specification.new 'samson_kubernetes', '0.0.1' do |s|
  s.summary = 'Allow deploying projects using Kubernetes'
  s.description = 'TBD'
  s.authors = ['Jon Moter', 'Maciek Sufa', 'Sergio Nunes', 'Shane Hender']
  s.email = 'jmoter@zendesk.com'
  s.add_runtime_dependency 'kubeclient', '>= 1.1'
  s.add_runtime_dependency 'celluloid'
  s.add_runtime_dependency 'celluloid-io'
end
