# frozen_string_literal: true
module SamsonGcloud
  class ImageTagger
    class << self
      # Note: not tagging builds from different project since that would be confusing ...
      # ideally do not tag any builds for projects that use shared builds ... but that is hard to know atm
      def tag(deploy)
        return unless ENV["DOCKER_FEATURE"]
        return unless deploy.succeeded?
        return unless builds = deploy.project.builds.
          where(git_sha: deploy.job.commit).where.not(docker_repo_digest: nil).to_a.presence

        gcloud_options = Shellwords.split(ENV.fetch('GCLOUD_IMG_TAGGER_OPTS', ''))

        builds.each do |build|
          digest = build.docker_repo_digest
          next unless digest =~ /(^|\/|\.)gcr.io\// # gcr.io or https://gcr.io or region like asia.gcr.io
          base = digest.split('@').first
          tag = deploy.stage.permalink
          command = [
            "gcloud", *SamsonGcloud.container_in_beta, "container", "images", "add-tag", digest, "#{base}:#{tag}",
            "--quiet", *gcloud_options
          ]
          success, output = Samson::CommandExecutor.execute(*command, timeout: 10)
          deploy.job.append_output!(
            "Tagging GCR image:\n#{command.join(" ")}\n#{output.strip}\n#{success ? "SUCCESS" : "FAILED"}\n"
          )
        end
      end
    end
  end
end
