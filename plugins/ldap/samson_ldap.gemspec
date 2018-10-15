# frozen_string_literal: true
Gem::Specification.new 'samson_ldap', '0.0.1' do |s|
  s.summary = 'ldap auth'
  s.description = s.summary
  s.authors = ['Michael Grosser']
  s.email = 'mgrosser@zendesk.com'
  s.add_runtime_dependency 'omniauth-ldap'
end
