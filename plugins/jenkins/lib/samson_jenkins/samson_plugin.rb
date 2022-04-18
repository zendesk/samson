# frozen_string_literal: true
module SamsonJenkins
  class SamsonPlugin < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_jenkins"
Samson::Hooks.view :deploys_header, "samson_jenkins"

Samson::Hooks.callback :stage_permitted_params do
  [
    :jenkins_job_names,
    :jenkins_email_committers,
    :jenkins_build_params
  ]
end

Samson::Hooks.callback :after_deploy do |deploy, _|
  Samson::Jenkins.deployed!(deploy)
end

# silence warning see https://stackoverflow.com/questions/65423458/ruby-2-7-says-uri-escape-is-obsolete-what-replaces-it
# and https://github.com/arangamani/jenkins_api_client/blob/master/lib/jenkins_api_client/urihelper.rb
# can remove once we use >1.5.3
require 'jenkins_api_client'
JenkinsApi::UriHelper.define_method(:path_encode) do |path|
  Addressable::URI.escape(path.encode(Encoding::UTF_8)) # uncovered
end
