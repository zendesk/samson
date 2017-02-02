# frozen_string_literal: true
module SamsonDockerBinaryBuilder
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, 'samson_docker_binary_builder/stage_fields'

Samson::Hooks.callback :before_docker_build do |dir, build, output|
  BinaryBuilder.new(dir, build.project, build.git_ref, output).build
end

Samson::Hooks.callback :after_deploy_setup do |dir, job, output, reference|
  if job.deploy&.stage&.docker_binary_plugin_enabled
    BinaryBuilder.new(dir, job.project, reference, output).build
  end
end

Samson::Hooks.callback :stage_permitted_params do
  :docker_binary_plugin_enabled
end
