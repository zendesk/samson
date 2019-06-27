# frozen_string_literal: true
module SamsonJenkins
  class Engine < Rails::Engine
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
