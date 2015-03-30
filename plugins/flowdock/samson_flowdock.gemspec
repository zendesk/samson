Gem::Specification.new 'samson_flowdock', '0.0.0' do |s|
  s.summary = 'Samson flowdock integration'
  s.authors = ['Michael Grosser']
  s.email = 'michael@grosser.it'
  s.add_runtime_dependency 'flowdock', '~> 0.5.0'
  s.files = Dir['{app,config,db,lib}/**/*']
  s.test_files = Dir['test/**/*.rb']
end
