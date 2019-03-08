# frozen_string_literal: true
Gem::Specification.new 'samson_gitlab', '0.0.0' do |s|
  s.summary = 'Samson gitlab plugin'
  s.authors = ['Igor Sharshun']
  s.email = ['igorsharshun@gmail.com']
  s.files = Dir['{app,config,db,lib}/**/*']

  s.add_runtime_dependency 'git_diff_parser'
  s.add_runtime_dependency 'gitlab'
end
