Gem::Specification.new 'samson_deploy_waitlist', '0.0.0' do |s|
  s.summary = 'Samson DeployWaitlist plugin'
  s.authors = ['Marc Cull']
  s.email = ['mcull@lumoslabs.com']
  s.files = Dir['{app,config,db,lib}/**/*']

  s.add_dependency "clockwork"
end
