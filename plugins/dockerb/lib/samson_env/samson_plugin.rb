module SamsonDockerb
  class Engine < Rails::Engine
  end
end

Samson::Hooks.callback :after_deploy_setup do |dir, _stage|
  if File.exist?("#{dir}/Dockerfile.erb") && !File.exist?("#{dir}/Dockerfile")
    require 'dockerb'
    Dir.chdir(dir) do
      begin
        Dockerb.compile
      rescue
        raise Samson::Hooks::UserError, $!.message
      end
    end
  end
end
