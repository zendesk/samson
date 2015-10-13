module SamsonDockerBinaryBuilder
  class Engine < Rails::Engine
  end
end

Samson::Hooks.callback :before_docker_build do |dir, build, output|
  BinaryBuilder.new(dir, build.project, build.git_ref, output).build
end

Samson::Hooks.callback :after_deploy_setup do |dir, job, output, reference|
  BinaryBuilder.new(dir, job.project, reference, output).build
end
