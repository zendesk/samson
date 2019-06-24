# frozen_string_literal: true
module SamsonGcloud
  class ImageTagger
    PRODUCTION_TAG = 'production'

    class << self
      # Note: not tagging builds from different project since that would be confusing ...
      # ideally do not tag any builds for projects that use shared builds ... but that is hard to know atm
      def tag(deploy, output)
        return unless needs_tag?(deploy)

        builds = deploy.project.builds.
          where(git_sha: deploy.job.commit).
          where.not(docker_repo_digest: nil)

        builds.each do |build|
          digest = build.docker_repo_digest
          next unless SamsonGcloud.gcr?(digest)
          base = digest.split('@').first
          cache_last_tagged [base, PRODUCTION_TAG], digest do
            tag_image PRODUCTION_TAG, base, digest, output
          end
        end
      end

      private

      def needs_tag?(deploy)
        ENV["DOCKER_FEATURE"] && deploy.succeeded? && deploy.stage.production? && !deploy.stage.no_code_deployed?
      end

      def tag_image(tag, base, digest, job_output)
        command = [
          "gcloud", "container", "images", "add-tag", digest, "#{base}:#{tag}", "--quiet", *SamsonGcloud.cli_options
        ]
        success, output = Samson::CommandExecutor.execute(*command, timeout: 10, whitelist_env: ["PATH"])
        job_output.write <<~TEXT
          #{Samson::OutputUtils.timestamp} Tagging GCR image:
          #{command.join(" ")}
          #{output.strip}
        TEXT
        job_output.puts "FAILED" unless success
        success
      end

      def cache_last_tagged(key, value)
        old = Rails.cache.read(key)
        if old == value
          Rails.cache.write(key, value) # refresh the cache expiration
        else
          Rails.cache.write(key, value) if yield # mark as tagged
        end
      end
    end
  end
end
