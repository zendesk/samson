# frozen_string_literal: true
module SamsonGcloud
  class ImageBuilder
    class << self
      def build_image(dir, build, executor, tag_as_latest:, cache_from:)
        prefix = "gcr.io/#{SamsonGcloud.project}/samson"
        fake_registry = OpenStruct.new(base: prefix)
        base = build.project.docker_repo(fake_registry, build.dockerfile)
        tags = [build.git_sha]
        tags << "latest" if tag_as_latest
        tag_arguments = tags.map { |t| "'--tag', '#{base}:#{t}'" }.join(", ")
        tag_list = tags.map { |t| "- '#{t}'" }.join("\n")

        # build would fail on image that does not exist, so we check before pulling
        if cache_from
          if image_exists_in_gcloud?(cache_from)
            cache_pull = "\n#{<<~YAML.strip}"
              - name: 'gcr.io/cloud-builders/docker'
                args: ['pull', '#{cache_from}']
            YAML
            cache_options = ", '--cache-from', '#{cache_from}'"
          else
            executor.output.puts "Image #{cache_from} not found in gcr, not using cache."
          end
        end

        config = "#{dir}/cloudbuild.yml" # inside of the directory or we get 'Could not parse into a message'
        if File.exist?(config)
          raise Samson::Hooks::UserError, "cloudbuild.yml already exists, use external builds"
        end

        File.write(config, <<~YAML)
          steps:#{cache_pull}
          - name: 'gcr.io/cloud-builders/docker'
            args: [ 'build', #{tag_arguments}, '--file', '#{build.dockerfile}'#{cache_options}, '.' ]
          images:
          - '#{base}'
          tags:
          #{tag_list}
        YAML

        prevent_upload_of_ignored_files(dir, build)

        container = (gcloud_version >= Gem::Version.new("238.0.0") ? [] : ["container"])
        command = [
          "gcloud", *container, "builds", "submit", ".",
          "--timeout", executor.timeout, "--config", config, *SamsonGcloud.cli_options
        ]

        return unless executor.execute(
          "cd #{dir.shellescape}",
          command.shelljoin
        )

        log = executor.output.messages
        build.external_url = log[/Logs are permanently available at \[(.*?)\]/, 1]
        return unless digest = log[/digest: (\S+:\S+)/, 1]
        "#{base}@#{digest}"
      end

      private

      def gcloud_version
        @gcloud_version ||= Gem::Version.new(`gcloud version`[/Google Cloud SDK (.*)/, 1] || "9999")
      end

      def prevent_upload_of_ignored_files(dir, build)
        ignore = "#{dir}/.gcloudignore"
        unless File.exist?(ignore)
          dockerignore = "#{dir}/.dockerignore"
          dockerignore_exists = File.exist?(dockerignore)

          # ignoring the dockerfile leads to a weird error message, so avoid it
          if dockerignore_exists
            File.write(dockerignore, File.read(dockerignore).sub(/^#{Regexp.escape(build.dockerfile)}$/, ''))
          end

          File.write(
            ignore,
            [
              ("#!include:.gitignore" if File.exist?("#{dir}/.gitignore")),
              (dockerignore_exists ? "#!include:.dockerignore" : ".git")
            ].compact.join("\n")
          )
        end
      end

      # NOTE: not using executor since it does not return output
      def image_exists_in_gcloud?(repo_digest)
        image, digest = repo_digest.split('@')
        output = Samson::CommandExecutor.execute(
          "gcloud", "container", "images", "list-tags", image,
          "--format", "get(digest)", "--filter", "digest=#{digest}", *SamsonGcloud.cli_options,
          timeout: 10
        ).last
        output.strip == digest
      end
    end
  end
end
