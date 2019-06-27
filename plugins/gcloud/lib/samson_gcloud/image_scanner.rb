# frozen_string_literal: true
module SamsonGcloud
  class ImageScanner
    WAITING = 0
    SUCCESS = 1
    FOUND = 2
    ERROR = 3
    UNSUPPORTED = 4

    FINISHED = [SUCCESS, FOUND, UNSUPPORTED].freeze

    class << self
      # found by inspecting
      # gcloud alpha container images list-tags gcr.io/$PROJECT_ID/base/alpine --show-occurrences --log-http
      # which has many thousand occurrence for very simple images
      # the occurrence with type DISCOVERY tells us the scan status
      # https://cloud.google.com/container-registry/docs/reference/rest/v1alpha1/projects.occurrences#analysisstatus
      def scan(image)
        expires_in = ->(status) { FINISHED.include?(status) ? 1.day : 0 }
        Samson::DynamicTtlCache.cache_fetch_if(true, "gcloud-scan-#{image}", expires_in: expires_in) do
          uncached_scan(image)
        end
      end

      def result_url(image)
        return unless digest_base = digest_base(image)
        "https://console.cloud.google.com/gcr/images/#{SamsonGcloud.project}/GLOBAL#{digest_base}/details/vulnz"
      end

      def status(id)
        case id
        when WAITING then "Waiting for Vulnerability scan"
        when SUCCESS then "No vulnerabilities found"
        when FOUND then "Vulnerabilities found"
        when ERROR then "Error retrieving vulnerabilities"
        when UNSUPPORTED then "Only full gcr repos in #{SamsonGcloud.project} with shas are supported for scanning"
        else raise "Unknown id #{id}"
        end
      end

      private

      def digest_base(image)
        return unless image
        return unless image.include? "@" # only scanning shas is supported, not tags
        image.split(SamsonGcloud.project, 2)[1]
      end

      # gcr only offers one endpoint that returns both "scan is finished" events (discovery) and
      # "vulnerability found" events (package vulnerability).
      # If we get an empty result set, we dont not know if there are no vulnerability or if a scan has not started
      # so we need to see if there is a discovery and if there are vulnerabilities.
      # NOTE: If we could guarantee ordering we could make a single request for
      # "(kind=\"DISCOVERY\" OR kind=\"PACKAGE_VULNERABILITY\")"
      def uncached_scan(image)
        return UNSUPPORTED unless digest_base(image)
        return ERROR unless result = request(image, "occurrences", "kind=\"DISCOVERY\"")

        status = result.dig("occurrences", 0, "discovered", "discovered", "analysisStatus")
        if status != "FINISHED_SUCCESS"
          return ["PENDING", "SCANNING"].include?(status) ? WAITING : ERROR
        end

        return ERROR unless result = request(image, "occurrences", "kind=\"PACKAGE_VULNERABILITY\"")
        result.empty? ? SUCCESS : FOUND
      end

      def request(image, path, filter = nil)
        image = "https://#{image}" unless image.start_with?("http")
        filter = (["resourceUrl=\"#{image}\""] + Array(filter)).join(" AND ")
        response = nil

        3.times do
          begin
            response = Faraday.get(
              "https://containeranalysis.googleapis.com/v1beta1/projects/#{SamsonGcloud.project}/#{path}",
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
          raise "GCLOUD ERROR: #{result}" unless success
          result
        end
      end
    end
  end
end
