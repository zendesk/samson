Gem::Specification.new 'samson_flowdock', '0.0.0' do |s|
  s.summary = 'Samson flowdock integration'
  s.authors = ['Michael Grosser', 'Fabio Neves']
  s.email = ['michael@grosser.it', 'fneves@zendesk.com']
  s.add_runtime_dependency 'flowdock', '~> 0.5.0'
  s.files = Dir['{app,config,db,lib}/**/*']
end
