# frozen_string_literal: true
module SamsonGcloud
  class ImageScanner
    WAITING = 0
    SUCCESS = 1
    FOUND = 2
    ERROR = 3

    FINISHED = [SUCCESS, FOUND].freeze

    class << self
      # found by inspecting
      # gcloud alpha container images list-tags gcr.io/$PROJECT_ID/base/alpine --show-occurrences --log-http
      # which has many thousand occurances for very simple images
      # the occurance with type DISCOVERY tells us if the scan is done, so we do not mark pending as "Nothing found"
      def scan(build)
        return ERROR unless result = request(build, "occurrences", "kind=\"DISCOVERY\"")
        return WAITING unless result.dig("occurrences", 0, "discovered", "operation", "done")
        return ERROR unless result = request(build, "vulnzsummary")
        result.empty? ? SUCCESS : FOUND
      end

      def result_url(build)
        return unless digest = build.docker_repo_digest
        digest_base = digest.split(SamsonGcloud.project).last
        "https://console.cloud.google.com/gcr/images/#{SamsonGcloud.project}/GLOBAL#{digest_base}/details/vulnz"
      end

      def status(id)
        case id
        when WAITING
          "Waiting for Vulnerability scan"
        when SUCCESS
          "No vulnerabilities found"
        when FOUND
          "Vulnerabilities found"
        when ERROR
          "Error retrieving vulnerabilities"
        else raise
        end
      end

      private

      def request(build, path, filter = nil)
        url = build.docker_repo_digest
        url = "https://#{url}" unless url.start_with?("http")
        filter = (["resourceUrl=\"#{url}\""] + Array(filter)).join(" AND ")
        response = nil

        3.times do
          begin
            response = Faraday.get(
              "https://containeranalysis.googleapis.com/v1alpha1/projects/#{SamsonGcloud.project}/#{path}",
              {filter: filter},
              authorization: "Bearer #{token}"
            )
          rescue
            Rails.logger.error("Unable to fetch vulnerabilities: #{$!}")
            return
          end
          break if response.status < 500 # we saw lots of 503 error when trying this out
        end

        unless response.status == 200
          Rails.logger.error("Unable to fetch vulnerabilities: #{response.status} -- #{response.body}")
          return
        end

        JSON.parse(response.body)
      end

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
