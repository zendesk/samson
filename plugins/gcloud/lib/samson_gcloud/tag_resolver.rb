# frozen_string_literal: true
#
# https://cloud.google.com/sdk/gcloud/reference/container/images/describe
# Could also be done via docker api https://docs.docker.com/registry/spec/api/#existing-manifests
# but then needs a token-auth step.
module SamsonGcloud
  class TagResolver
    class << self
      def resolve_docker_image_tag(image)
        return unless SamsonGcloud.gcr? image
        return if image.match? Build::DIGEST_REGEX

        result = Samson::CommandExecutor.execute(
          "gcloud", "container", "images", "describe", image, "--format", "json",
          *SamsonGcloud.cli_options,
          timeout: 10,
          whitelist_env: ["PATH"]
        )
        raise "GCLOUD ERROR: unable to resolve #{image}\n#{result[:error]}" unless result[:status]
        digest = JSON.parse(result[:output]).dig_fetch("image_summary", "digest")

        base = image.split(":", 2).first
        "#{base}@#{digest}"
      end
    end
  end
end
