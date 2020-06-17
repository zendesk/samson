# frozen_string_literal: true

module RollbarDashboards
  class Client
    MAX_RQL_JOB_WAIT_TIME = 5
    REQUEST_TIMEOUT = 5

    def initialize(dashboard)
      @base = dashboard.base_url
      @token = Samson::Secrets::KeyResolver.new(dashboard.project, []).resolved_attribute(dashboard.read_token)
    end

    # returns array hashes of top items
    def top_errors(hours:, environments:)
      args = {
        access_token: @token,
        hours: hours,
        environments: environments.join(',')
      }.to_query

      request :get, "#{@base}/reports/top_active_items?#{args}" do |data|
        data.fetch(:result).map { |item_hash| item_hash.fetch(:item) }
      end
    end

    # creates a new rql job
    def create_rql_job(query_string)
      params = {
        access_token: @token,
        query_string: query_string,
        force_refresh: 1
      }
      request :post, "#{@base}/rql/jobs", params do |data|
        data.dig_fetch(:result, :id)
      end
    end

    # gets the rql job result, returns array of hashes e.g. [{ col1: row_val_1 ...}, { col1: row_val_2 ...}]
    def rql_job_result(id)
      MAX_RQL_JOB_WAIT_TIME.times do |i|
        request :get, "#{@base}/rql/job/#{id}/result?access_token=#{@token}" do |data|
          if data.dig_fetch(:result, :result).nil?
            Rails.logger.info "Waiting for RQL job #{id}"
            sleep 1 if i < (MAX_RQL_JOB_WAIT_TIME - 1)
          else
            columns = data.dig_fetch(:result, :result, :columns).map(&:to_sym)
            rows = data.dig_fetch(:result, :result, :rows)
            return rows.map { |row| columns.zip(row).to_h }.presence
          end
        end
      end

      raise Samson::Hooks::UserError, "Timeout retrieving RQL job #{id} result"
    end

    def request(method, url, *args)
      response = Faraday.send(method, url, *args) do |req|
        req.options.timeout = req.options.open_timeout = REQUEST_TIMEOUT
      end
      raise "Response #{response.status}" unless response.success?
      yield JSON.parse(response.body, symbolize_names: true)
    rescue StandardError
      Samson::ErrorNotifier.notify($!)
      raise Samson::Hooks::UserError, "Failed to contact rollbar"
    end
  end
end
