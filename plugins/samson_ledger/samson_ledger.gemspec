# frozen_string_literal: true
Gem::Specification.new 'samson_ledger', '0.0.1' do |s|
  s.summary = 'client to allow posting events to ledger (internal zendesk system)'
  s.description = s.summary
  s.authors = ['ian Waters']
  s.email = 'iwaters@zendesk.com'
  s.add_runtime_dependency 'faraday'
end
