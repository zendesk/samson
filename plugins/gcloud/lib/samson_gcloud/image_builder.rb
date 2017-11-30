# frozen_string_literal: true
module SamsonGcloud
  class ImageBuilder
    class << self
      # TODO: use build.dockerfile
      def build_image(build, dir, output, dockerfile:)
        fake_registry = OpenStruct.new(base: "gcr.io/#{SamsonGcloud.project}/samson")
        base = build.project.docker_repo(fake_registry, dockerfile)
        config = "#{dir}/cloudbuild.yml" # inside of the directory or we get 'Could not parse into a message'
        tag = "#{base}:#{build.git_sha}"

        File.write(config, <<~YAML)
          steps:
          - name: 'gcr.io/cloud-builders/docker'
            args: [ 'build', '--tag', '#{tag}', '--file', '#{dockerfile}', '.' ]
          images:
          - '#{tag}'
        YAML

        command = [
          "gcloud", *SamsonGcloud.container_in_beta, "container", "builds", "submit", ".",
          "--config", config, *SamsonGcloud.cli_options
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
