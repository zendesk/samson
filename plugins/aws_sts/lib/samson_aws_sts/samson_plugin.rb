module SamsonAwsSts
  class Engine < Rails::Engine
  end
end

# To add in your own UI for a hook, e.g., for the stage edit page:
# - Create app/views/samson_aws_sts/_my_fields.html.erb
# - Add this line to this file, note the lack of leading underscore and extension:
Samson::Hooks.view :stage_form, 'samson_aws_sts/fields'

Samson::Hooks.callback :stage_permitted_params do
  [
    :aws_sts_iam_role_arn
  ]
end

#Samson::Hooks.view :stage_form, '<view path>'

#Samson::Hooks.view :stage_show, '<view path>'

#Samson::Hooks.view :stage_form_checkbox, '<view path>'

#Samson::Hooks.view :project_form, '<view path>'

#Samson::Hooks.view :project_form_checkbox, '<view path>'

#Samson::Hooks.view :build_button, '<view path>'

#Samson::Hooks.view :build_new, '<view path>'

#Samson::Hooks.view :build_show, '<view path>'

#Samson::Hooks.view :deploy_confirmation_tab_nav, '<view path>'

#Samson::Hooks.view :deploy_confirmation_tab_body, '<view path>'

#Samson::Hooks.view :deploy_group_show, '<view path>'

#Samson::Hooks.view :deploy_group_form, '<view path>'

#Samson::Hooks.view :deploy_group_table_header, '<view path>'

#Samson::Hooks.view :deploy_group_table_cell, '<view path>'

#Samson::Hooks.view :deploys_header, '<view path>'

#Samson::Hooks.view :deploy_show_view, '<view path>'

#Samson::Hooks.view :deploy_tab_nav, '<view path>'

#Samson::Hooks.view :deploy_tab_body, '<view path>'

#Samson::Hooks.view :deploy_view, '<view path>'

#Samson::Hooks.view :deploy_form, '<view path>'

#Samson::Hooks.view :admin_menu, '<view path>'

#Samson::Hooks.view :manage_menu, '<view path>'

#Samson::Hooks.view :project_tabs_view, '<view path>'

#Samson::Hooks.view :project_view, '<view path>'


# Possible callbacks are listed below, delete any unused ones.

#Samson::Hooks.callback :after_deploy do
  # Do stuff in here
#end

#Samson::Hooks.callback :after_deploy_setup do
  # Do stuff in here
#end

#Samson::Hooks.callback :after_docker_build do
  # Do stuff in here
#end

#Samson::Hooks.callback :after_job_execution do
  # Do stuff in here
#end

#Samson::Hooks.callback :before_deploy do
  # Do stuff in here
#end

#Samson::Hooks.callback :before_docker_build do
  # Do stuff in here
#end

#Samson::Hooks.callback :before_docker_repository_usage do
  # Do stuff in here
#end

#Samson::Hooks.callback :buddy_request do
  # Do stuff in here
#end

#Samson::Hooks.callback :build_permitted_params do
  # Do stuff in here
#end

#Samson::Hooks.callback :buildkite_release_params do
  # Do stuff in here
#end

#Samson::Hooks.callback :can do
  # Do stuff in here
#end

#Samson::Hooks.callback :deploy_group_env do
  # Do stuff in here
#end

#Samson::Hooks.callback :deploy_group_includes do
  # Do stuff in here
#end

#Samson::Hooks.callback :deploy_group_permitted_params do
  # Do stuff in here
#end

#Samson::Hooks.callback :deploy_permitted_params do
  # Do stuff in here
#end

#Samson::Hooks.callback :ensure_build_is_successful do
  # Do stuff in here
#end

#Samson::Hooks.callback :error do
  # Do stuff in here
#end

#Samson::Hooks.callback :ignore_error do
  # Do stuff in here
#end

#Samson::Hooks.callback :job_additional_vars do
  # Do stuff in here
#end

#Samson::Hooks.callback :link_parts_for_resource do
  # Do stuff in here
#end

#Samson::Hooks.callback :project_docker_build_method_options do
  # Do stuff in here
#end

#Samson::Hooks.callback :project_permitted_params do
  # Do stuff in here
#end

#Samson::Hooks.callback :ref_status do
  # Do stuff in here
#end

#Samson::Hooks.callback :release_deploy_conditions do
  # Do stuff in here
#end

#Samson::Hooks.callback :stage_clone do
  # Do stuff in here
#end

#Samson::Hooks.callback :stage_permitted_params do
  # Do stuff in here
#end

#Samson::Hooks.callback :trace_method do
  # Do stuff in here
#end

#Samson::Hooks.callback :asynchronous_performance_tracer do
  # Do stuff in here
#end

