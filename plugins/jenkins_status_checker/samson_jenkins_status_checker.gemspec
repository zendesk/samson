# frozen_string_literal: true
Gem::Specification.new 'samson_jenkins_status_checker', '0.0.0' do |s|
  s.summary = 'Samson Jenkins Status Checker plugin'
  s.authors = ['Yi Fei Wu']
  s.email = ['ywu@zendesk.com']
  s.files = Dir['{app,config,db,lib}/**/*']
  s.add_runtime_dependency "jenkins_api_client", "~> 2.0"
end
