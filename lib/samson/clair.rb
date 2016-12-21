# frozen_string_literal: true
#
# Hyperclair will pull the image from registry and run scan with Clair scanner
# using a forked version with ENV var and / support
# https://github.com/zendesk/hyperclair
# discussion see https://github.com/wemanity-belgium/hyperclair/pull/90
module Samson
  # TODO: should check based on docker_repo_digest not tag
  # TODO: this should be a plugin instead and use hooks
  module Clair
    class << self
      def append_job_with_scan(job, docker_tag)
        return unless clair = ENV['HYPERCLAIR_PATH']

        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            sleep 0.1 if Rails.env.test? # in test we reuse the same connection, so we cannot use it at the same time
            success, output, time = scan(clair, job.project, docker_tag)
            status = (success ? "success" : "errored or vulnerabilities found")
            output = "### Clair scan: #{status} in #{time}s\n#{output}"
            job.reload
            job.update_column(:output, job.output + output)
          end
        end
      end

      private

      def scan(executable, project, docker_ref)
        with_time do
          Samson::CommandExecutor.execute(
            executable,
            *project.docker_repo.split('/', 2),
            docker_ref,
            whitelist_env: [
              'DOCKER_REGISTRY_USER',
              'DOCKER_REGISTRY_PASS',
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
end
