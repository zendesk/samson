# frozen_string_literal: true
module SamsonGcloud
  class ImageScanner
    WAITING = 0
    SUCCESS = 1
    FOUND = 2
    ERROR = 3

    FINISHED = [SUCCESS, FOUND].freeze

    # time to wait for scan to complete since we cannot tell pending from success
    # TODO: find a way to actually tell success from pending
    GRACE_PERIOD = 10.minutes

    class << self
      # found by inspecting
      # gcloud alpha container images list-tags gcr.io/$PROJECT_ID/base/alpine --show-occurrences --log-http
      def scan(build)
        return WAITING if build.updated_at > GRACE_PERIOD.ago

        url = build.docker_repo_digest
        url = "https://#{url}" unless url.start_with?("http")

        # NOTE: if we want more details we need to check occurrences instead with pageSize=100 and paginate
        begin
          response = Faraday.get(
            "https://containeranalysis.googleapis.com/v1alpha1/projects/#{SamsonGcloud.project}/vulnzsummary",
            {filter: "resourceUrl=\"#{url}\""},
            authorization: "Bearer #{token}"
          )
        rescue
          Rails.logger.error("Unable to fetch vulnerabilities: #{$!}")
          return ERROR
        end

        unless response.status == 200
          Rails.logger.error("Unable to fetch vulnerabilities: #{response.status} -- #{response.body}")
          return ERROR
        end

        JSON.parse(response.body).empty? ? SUCCESS : FOUND
      end

      def result_url(build)
        return unless digest = build.docker_repo_digest
        digest_base = digest.split(SamsonGcloud.project).last
        "https://console.cloud.google.com/gcr/images/#{SamsonGcloud.project}/GLOBAL#{digest_base}/details/vulnz"
      end

      def status(id)
        case id
        when WAITING
          "Must wait #{GRACE_PERIOD / 1.minute}min before scanning build"
        when SUCCESS
          "No vulnerabilities found"
        when FOUND
          "Vulnerabilities found"
        when ERROR
          "Error retriving vulnerabilities"
        else raise
        end
      end

      private

      # token expires after 30 min, so we keep it for 28 with a 1 minute grace period
      def token
        Rails.cache.fetch("gcloud-image-scanner-token", expires_in: 28.minutes, race_condition_ttl: 1.minute) do
          success, result = Samson::CommandExecutor.execute(
            "gcloud", "auth", "print-access-token", *SamsonGcloud.cli_options,
            timeout: 5,
            whitelist_env: ["PATH"]
          )
          raise "GCLOUD ERROR: #{success}" unless success
          result
        end
      end
    end
  end
end
