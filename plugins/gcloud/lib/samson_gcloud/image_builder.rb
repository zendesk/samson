# frozen_string_literal: true
module SamsonGcloud
  class ImageBuilder
    class << self
      def build_image(build, dir, output, dockerfile:)
        raise "Only supports building Dockerfile atm" if dockerfile != "Dockerfile"

        repo = build.project.repository_path.parameterize
        base = "gcr.io/#{SamsonGcloud.project}/samson/#{repo}"
        tag = "#{base}:#{build.git_sha}"
        command = [
          "gcloud", *SamsonGcloud.container_in_beta, "container", "builds", "submit", ".",
          "--tag", tag, *SamsonGcloud.cli_options
        ]

        executor = TerminalExecutor.new(output)
        return unless executor.execute(
          "cd #{dir.shellescape}",
          executor.verbose_command(command.join(" "))
        )
        log = output.to_s
        build.external_url = log[/Logs are permanently available at \[(.*?)\]/, 1]
        return unless digest = log[/digest: (\S+:\S+)/, 1]
        "#{base}@#{digest}"
      end
    end
  end
end
