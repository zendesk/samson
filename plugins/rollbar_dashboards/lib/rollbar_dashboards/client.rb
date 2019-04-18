# frozen_string_literal: true

module RollbarDashboards
  class Client
    MAX_RQL_JOB_WAIT_TIME = 5
    REQUEST_TIMEOUT = 1

    def initialize(dashboard)
      @base = dashboard.base_url
      @token = Samson::Secrets::KeyResolver.new(dashboard.project, []).resolved_attribute(dashboard.read_token)
    end

    # returns array hashes of top items
    def top_errors(hours: 24, environments: ['production'])
      args = {
        access_token: @token,
        hours: hours,
        environments: environments.join(',')
      }.to_query

      response = Faraday.get("#{@base}/reports/top_active_items?#{args}") do |req|
        req.options.timeout = req.options.open_timeout = REQUEST_TIMEOUT
      end

      if response.success?
        data = ::JSON.parse(response.body, symbolize_names: true)
        data.fetch(:result).map { |item_hash| item_hash.fetch(:item) }
      end
    rescue StandardError
      Samson::ErrorNotifier.notify($!)
      nil
    end

    # creates a new rql job
    def create_rql_job(query_string)
      args = {
        access_token: @token,
        query_string: query_string,
        force_refresh: 1
      }

      response = Faraday.post("#{@base}/rql/jobs", args) do |req|
        req.options.timeout = req.options.open_timeout = REQUEST_TIMEOUT
      end

      if response.success?
        Rails.logger.info "Created RQL job: #{response.body}"
        ::JSON.parse(response.body, symbolize_names: true).dig_fetch(:result, :id)
      end
    rescue StandardError
      Rails.logger.error "Failed to create RQL job"
      Samson::ErrorNotifier.notify($!)
      nil
    end

    # gets the rql job result, returns array of hashes e.g. [{ col1: row_val_1 ...}, { col1: row_val_2 ...}]
    def rql_job_result(id)
      MAX_RQL_JOB_WAIT_TIME.times do |i|
        response = Faraday.get("#{@base}/rql/job/#{id}/result?access_token=#{@token}") do |req|
          req.options.timeout = req.options.open_timeout = REQUEST_TIMEOUT
        end

        break unless response.success?

        data = ::JSON.parse(response.body, symbolize_names: true)

        if data.dig_fetch(:result, :result).nil?
          Rails.logger.info "Waiting for RQL job #{id}"
          sleep(1) if i < (MAX_RQL_JOB_WAIT_TIME - 1)
        else
          columns = data.dig_fetch(:result, :result, :columns).map(&:to_sym)
          rows = data.dig_fetch(:result, :result, :rows)

          return rows.map { |row| columns.zip(row).to_h }.presence
        end
      end

      nil
    rescue StandardError
      Rails.logger.error "Error retrieving RQL job #{id} result"
      Samson::ErrorNotifier.notify($!)
      nil
    end
  end
end
