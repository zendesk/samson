# frozen_string_literal: true
module SamsonJenkinsStatusChecker
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :deploy_form, "samson_jenkins_status_checker/deploy_form"
Samson::Hooks.view :project_form_checkbox, "samson_jenkins_status_checker/project_form_checkbox"

Samson::Hooks.callback :project_permitted_params do
  [:jenkins_status_checker]
end
