# frozen_string_literal: true
Gem::Specification.new "samson_jenkins", "0.0.0" do |s|
  s.summary = "Samson jenkins integration"
  s.authors = ["Rupinder Dhanoa "]
  s.email = "rdhanoa@zendesk.com"
  s.add_runtime_dependency "jenkins_api_client2", "~> 1.9" # see https://github.com/arangamani/jenkins_api_client/issues/304
end
