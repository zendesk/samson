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
      # which has many thousand occurrence for very simple images
      # the occurrence with type DISCOVERY tells us the scan status
      # https://cloud.google.com/container-registry/docs/reference/rest/v1alpha1/projects.occurrences#analysisstatus
      def scan(build)
        return ERROR unless result = request(build, "occurrences", "kind=\"DISCOVERY\"")

        status = result.dig("occurrences", 0, "discovered", "analysisStatus")
        if status != "FINISHED_SUCCESS"
          return ["PENDING", "SCANNING"].include?(status) ? WAITING : ERROR
        end

        return ERROR unless result = request(build, "occurrences", "kind=\"PACKAGE_VULNERABILITY\"")
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
              {filter: filter, pageSize: 1},
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
