# frozen_string_literal: true
Gem::Specification.new 'samson_sentry', '0.0.0' do |s|
  s.summary = 'Samson Sentry plugin'
  s.authors = ['zendesk-mattlefevre']
  s.email = ['matthew.lefevre@zendesk.com']
  s.files = Dir['{app,config,db,lib}/**/*']

  s.add_runtime_dependency 'sentry-rails'
  s.add_runtime_dependency 'sentry-user_informer'
end
