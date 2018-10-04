# frozen_string_literal: true

Gem::Specification.new 'samson_aws_sts', '0.0.0' do |s|
  s.summary = 'Samson AwsSts plugin'
  s.authors = ['Gerard Cahill']
  s.email = ['gcahill@zendesk.com']
  s.files = Dir['{app,config,db,lib}/**/*']
  s.add_runtime_dependency "aws-sdk-core"
end
