# frozen_string_literal: true

Gem::Specification.new 'samson_airbrake', '0.0.0' do |s|
  s.summary = 'Samson Airbrake plugin'
  s.authors = ['Ryan Gurney']
  s.email = ['rygurney@zendesk.com']
  s.files = Dir['{app,config,db,lib}/**/*']

  s.add_runtime_dependency 'airbrake'
end
