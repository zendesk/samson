# frozen_string_literal: true
#
# ledger event client
#
require 'faraday'
require 'openssl'

module SamsonLedger
  class Client
    LEDGER_PATH = "/api/v1/events"

    class << self
      def post_deployment(deploy)
        post_event(deploy) if ledger_token && ledger_base_url && !deploy.stage.no_code_deployed?
      rescue StandardError
        Samson::ErrorNotifier.notify($!, notice: true)
      end

      private

      def ledger_token
        ENV["LEDGER_TOKEN"]
      end

      def ledger_base_url
        ENV["LEDGER_BASE_URL"]
      end

      def post_event(deploy)
        results = post(build_event(deploy))
        if results.status.to_i != 200
          Rails.logger.error("Ledger Client got a #{results.status} from #{ledger_base_url}")
        end
        results
      end

      def build_event(deploy)
        event = {
          id:            deploy.id,
          name:          deploy.project.name,
          actor:         deploy.user.name,
          status:        deploy.status,
          started_at:    deploy.updated_at.iso8601,
          summary:       deploy.summary,
          environment:   deploy.stage.deploy_groups.map(&:environment).uniq.map(&:permalink).map(&:downcase).join(","),
          url:           deploy.url,
          pods:          pods(deploy.stage.deploy_groups),
          pull_requests: pull_requests(deploy.changeset)
        }
        {events: [event]}
      end

      def pods(deploy_groups)
        deploy_groups.map { |dg| dg.env_value[/^(pod|staging|master)(\d+).*/, 2] }.compact.map(&:to_i).sort
      end

      def pull_requests(changeset)
        # Note: All HTML is sanitized at rendering time on Ledger.
        results = changeset.pull_requests.map do |pull_request|
          github_users = pull_request.users.compact.map do |user|
            "<a href='#{user.url}'><img src='#{user.avatar_url}' width=20 height=20 /></a>"
          end

          <<~HTML.tr("\n", ' ')
            <li>
              #{github_users.join}
              <strong>##{pull_request.number}</strong>
              <a href='#{pull_request.url}' target='_blank'>#{pull_request.title}</a>
            </li>
          HTML
        end

        "<ul>#{results.join}</ul>" if results.any?
      end

      def post(data)
        Faraday.post ledger_base_url + LEDGER_PATH do |request|
          request.headers['Content-Type'] = "application/json"
          request.headers['Authorization'] = "Token token=#{ledger_token}"
          request.body = data.to_json
        end
      end
    end
  end
end
