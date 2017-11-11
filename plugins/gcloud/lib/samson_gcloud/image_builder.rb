# frozen_string_literal: true
module SamsonGcloud
  class ImageBuilder
    class << self
      def build_image(build, dir, output, dockerfile:)
        raise "Only supports building Dockerfile atm" if dockerfile != "Dockerfile"

        repo = build.project.repository_path.parameterize
        base = "gcr.io/#{gcloud_project_id.shellescape}/samson/#{repo}"
        tag = "#{base}:#{build.git_sha}"
        command = [
          "gcloud", *SamsonGcloud.container_in_beta, "container", "builds", "submit", ".",
          "--tag", tag, "--project", gcloud_project_id
        ]

        executor = TerminalExecutor.new(output)
        return unless executor.execute(
          "cd #{dir.shellescape}",
          executor.verbose_command(command.join(" "))
        )
        return unless digest = output.to_s[/digest: (\S+:\S+)/, 1]
        "#{base}@#{digest}"
      end

      private

      def gcloud_project_id
        ENV.fetch("GCLOUD_BUILDER_PROJECT_ID")
      end
    end
  end
end
