# frozen_string_literal: true
Gem::Specification.new 'samson_audit_log', '0.0.0' do |s|
  s.summary = 'Samson audit_log plugin'
  s.authors = ['Robert Ikeoka']
  s.email = ['rikeoka@zendesk.com']
  s.files = Dir['{app,config,db,lib}/**/*']
  s.add_runtime_dependency 'airbrake'
end
