# frozen_string_literal: true
module SamsonGcloud
  class ImageTagger
    PRODUCTION_TAG = 'production'

    class << self
      # Note: not tagging builds from different project since that would be confusing ...
      # ideally do not tag any builds for projects that use shared builds ... but that is hard to know atm
      def tag(deploy, output)
        return unless ENV["DOCKER_FEATURE"]
        return unless deploy.succeeded?
        return unless builds = deploy.project.builds.
          where(git_sha: deploy.job.commit).where.not(docker_repo_digest: nil).to_a.presence

        tags = tags(deploy)

        builds.each do |build|
          digest = build.docker_repo_digest
          next unless digest.match?(/(^|\/|\.)gcr.io\//) # gcr.io or https://gcr.io or region like asia.gcr.io
          base = digest.split('@').first

          tags.each { |tag| tag_image(tag, base, digest, output) }
        end
      end

      private

      def tags(deploy)
        tags = []
        stage = deploy.stage

        if stage.production? && !stage.no_code_deployed?
          tags << PRODUCTION_TAG
        end

        if env_permalink = stage.environments&.first&.permalink
          tags << "env-#{env_permalink}"
        end

        tags << "stage-#{stage.permalink}"

        # From docker distro: https://tinyurl.com/ycgh7qsp
        tags.grep(/^[\w][\w.-]{0,127}$/)
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
      end
    end
  end
end
