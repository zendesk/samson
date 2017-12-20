# frozen_string_literal: true
require 'docker'
require 'shellwords'

class ImageBuilder
  class << self
    def build_image(dir, executor, dockerfile:, tag: nil, cache_from: nil)
      local_docker_login do |login_commands|
        tag = " -t #{tag.shellescape}" if tag
        file = " -f #{dockerfile.shellescape}"

        executor.quiet do
          if cache_from
            pull_cache = executor.verbose_command("docker pull #{cache_from.shellescape} || true")
            cache_option = " --cache-from #{cache_from.shellescape}"
          end

          build = "docker build#{file}#{tag} .#{cache_option}"

          return unless executor.execute(
            "cd #{dir.shellescape}",
            *login_commands,
            *pull_cache,
            executor.verbose_command(build)
          )
        end
        image_id = executor.output.to_s.scan(/Successfully built (\S+)/).last&.first
        Docker::Image.get(image_id) if image_id
      end
    end

    # store logins in a temp file and make it not accidentally added via `ADD .`
    def local_docker_login
      Dir.mktmpdir 'samson-tmp-docker-config' do |docker_config_folder|
        # copy existing credentials
        regular_config = File.join(ENV["DOCKER_CONFIG"] || File.expand_path("~/.docker"), "config.json")
        File.write("#{docker_config_folder}/config.json", File.read(regular_config)) if File.exist?(regular_config)

        # add new temp credentials like ECR ... old docker versions need email and server in last position
        credentials = DockerRegistry.all.select { |r| r.password && r.username }.map do |r|
          username = r.username.shellescape
          password = r.password.shellescape
          email = (docker_major_version >= 17 ? "" : "--email no@example.com ")
          "docker login --username #{username} --password #{password} #{email}#{r.host.shellescape}"
        end

        # run commands and then cleanup after
        yield ["export DOCKER_CONFIG=#{docker_config_folder.shellescape}", *credentials]
      end
    end

    private

    # TODO: same as in config/initializers/docker.rb ... dry it up
    def docker_major_version
      @@docker_major_version ||= begin
        Timeout.timeout(0.2) { read_docker_version[/(\d+)\.\d+\.\d+/, 1].to_i }
      rescue Timeout::Error
        0
      end
    end

    # just here to get stubbed
    def read_docker_version
      `docker -v 2>/dev/null`
    end
  end
end
