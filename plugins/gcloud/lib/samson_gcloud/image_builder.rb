# frozen_string_literal: true
module SamsonGcloud
  class ImageBuilder
    class << self
      def build_image(build, dir, output, dockerfile:)
        raise "Only supports building Dockerfile atm" if dockerfile != "Dockerfile"

        repo = build.project.repository_path.parameterize
        base = "gcr.io/#{gcloud_project_id.shellescape}/samson/#{repo}"
        tag = "#{base}:#{build.git_sha}"
        command = ["gcloud", *SamsonGcloud.container_in_beta, "container", "builds", "submit", "--tag", tag, "."]

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
        @@gcloud_project_id ||= begin
          result = Samson::CommandExecutor.execute("gcloud", "config", "list", "--format", "json", timeout: 10).last
          JSON.parse(result.to_s[/^{.*/m], symbolize_names: true).dig_fetch(:core, :project)
        end
      end
    end
  end
end
