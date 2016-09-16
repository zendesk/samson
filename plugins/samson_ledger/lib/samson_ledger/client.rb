# frozen_string_literal: true
#
# basic ledger event client
#
require 'faraday'
require 'openssl'

module SamsonLedger
  class Client
    LEDGER_PATH = "/api/v1/events"
    class << self
      def plugin_enabled?
        if ENV["LEDGER_TOKEN"].nil? || ENV["LEDGER_BASE_URL"].nil?
          false
        else
          true
        end
      end

      def post_deployment(deploy)
        return false unless plugin_enabled?
        post_event(deploy)
      end

      private

      def post_event(deploy)
        results = post(build_event(deploy))
        if results.status.to_i != 200
          Rails.logger.error("Ledger Client got a #{results.status} from #{ENV.fetch("LEDGER_BASE_URL")}")
        end
        results
      end

      def build_event(deploy)
        event = {
          id:           deploy.id,
          name:         deploy.project.name,
          actor:        deploy.user.name,
          status:       deploy.status,
          started_at:   deploy.created_at.iso8601,
          summary:      deploy.summary,
          environment:  deploy.stage.deploy_groups.map(&:environment).uniq.map(&:permalink).map(&:downcase).join(","),
          url:          deploy.url,
          pods:         deploy.stage.deploy_groups.map(&:env_value)
        }
        { "events": [event] }
      end

      def post(data)
        connection = Faraday.new(url: ENV.fetch("LEDGER_BASE_URL") + LEDGER_PATH)
        connection.post do |request|
          request.headers['Content-Type'] = "application/json"
          request.headers['Authorization'] = "Token token=#{ENV.fetch("LEDGER_TOKEN")}"
          request.body = data.to_json
        end
      end
    end
  end
end
