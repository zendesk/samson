# frozen_string_literal: true
require 'shellwords'

class ImageBuilder
  class << self
    extend ::Samson::PerformanceTracer::Tracers

    DIGEST_SHA_REGEX = /Digest:.*(sha256:[0-9a-f]{64})/i.freeze

    def build_image(dir, build, executor, tag_as_latest:, **args)
      if DockerRegistry.all.empty?
        raise Samson::Hooks::UserError, "Need at least one DOCKER_REGISTRIES to push images"
      end
      return unless image_id = build_image_locally(
        dir, executor,
        tag: build.docker_tag, dockerfile: build.dockerfile, **args
      )
      push_image(image_id, build, executor, tag_as_latest: tag_as_latest)
    ensure
      if image_id && !['1', 'true'].include?(ENV["DOCKER_KEEP_BUILT_IMGS"])
        executor.execute(["docker", "rmi", "-f", image_id].shelljoin)
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

    def build_image_locally(dir, executor, dockerfile:, tag:, cache_from:)
      local_docker_login do |login_commands|
        tag = " -t #{tag.shellescape}" if tag
        file = " -f #{dockerfile.shellescape}"

        executor.quiet do
          if cache_from
            pull_cache = executor.verbose_command("docker pull #{cache_from.shellescape} || true")
            cache_option = " --cache-from #{cache_from.shellescape}"
          end

          build_command = "docker build#{file}#{tag} .#{cache_option}"

          return unless executor.execute(
            "cd #{dir.shellescape}",
            *login_commands,
            *pull_cache,
            executor.verbose_command(build_command)
          )
        end
        executor.output.messages.scan(/Successfully built ([a-f\d]{12,})/).last&.first
      end
    end

    def push_image(image_id, build, executor, tag_as_latest:)
      tag = build.docker_tag
      tag_is_latest = (tag == 'latest')

      unless repo_digest = push_image_to_registries(image_id, build, executor, tag: tag, override_tag: tag_is_latest)
        executor.output.puts("Docker push failed: Unable to get repo digest")
        return
      end

      if tag_as_latest && !tag_is_latest
        push_image_to_registries image_id, build, executor, tag: 'latest', override_tag: true
      end

      repo_digest
    end
    add_tracer :push_image

    def push_image_to_registries(image_id, build, executor, tag:, override_tag:)
      digest = nil

      DockerRegistry.all.each_with_index do |registry, i|
        primary = i == 0
        repo = build.project.docker_repo(registry, build.dockerfile)

        if override_tag
          executor.output.puts("### Tagging and pushing Docker image to #{repo}:#{tag}")
        else
          executor.output.puts("### Pushing Docker image to #{repo} without tag")
        end

        local_docker_login do |login_commands|
          full_tag = "#{repo}:#{tag}"

          executor.quiet do
            return nil unless executor.execute(
              *login_commands,
              executor.verbose_command(["docker", "tag", image_id, full_tag].shelljoin),
              executor.verbose_command(["docker", "push", full_tag].shelljoin)
            )
          end

          if primary
            # cache-from also produced digest lines, so we need to be careful
            last = executor.output.messages.split("\n").last.to_s
            return nil unless sha = last[DIGEST_SHA_REGEX, 1]
            digest = "#{repo}@#{sha}"
          end
        end
      end

      digest
    end

    # TODO: same as in config/initializers/docker.rb ... dry it up
    def docker_major_version
      @@docker_major_version ||=
        begin
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
