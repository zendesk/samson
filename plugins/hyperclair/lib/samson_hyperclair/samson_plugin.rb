# frozen_string_literal: true
# FIXME: check based on docker_repo_digest not tag
module SamsonHyperclair
  class Engine < Rails::Engine
  end

  class << self
    def append_build_job_with_scan(build)
      return unless clair = ENV['HYPERCLAIR_PATH']
      job = build.docker_build_job

      append_output job, "### Clair scan: started\n"

      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          sleep 0.1 if Rails.env.test? # in test we reuse the same connection, so we cannot use it at the same time
          success, output, time = scan(clair, build.docker_repo_digest)
          Airbrake.notify("Clair scan: dirty exit #{$?.exitstatus}", build: build.url) if $?.exitstatus > 1 # dirty exit
          status = (success ? "success" : "errored or vulnerabilities found")
          output = "### Clair scan: #{status} in #{time}s\n#{output}"
          append_output job, output
        end
      end
    end

    private

    # external builds have no job ... so we cannot store output
    def append_output(job, output)
      if job
        job.append_output!(output)
      else
        Rails.logger.info(output)
      end
    end

    def scan(executable, docker_repo_digest)
      registry = DockerRegistry.first

      with_time do
        Samson::CommandExecutor.execute(
          executable,
          docker_repo_digest,
          env: {
            'DOCKER_REGISTRY_USER' => registry.username,
            'DOCKER_REGISTRY_PASS' => registry.password
          },
          whitelist_env: [
            'AWS_ACCESS_KEY_ID',
            'AWS_SECRET_ACCESS_KEY',
            'PATH'
          ],
          timeout: 60 * 60
        )
      end
    end

    def with_time
      result = []
      time = Benchmark.realtime { result = yield }
      result << time
    end
  end
end

Samson::Hooks.callback :after_docker_build do |build|
  if build.docker_repo_digest
    SamsonHyperclair.append_build_job_with_scan(build)
  end
end
