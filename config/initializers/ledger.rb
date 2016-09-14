# frozen_string_literal: true
#
# basic ledger event client
#
require 'faraday'
require 'openssl'

LEDGER_HOST = ENV["LEDGER_HOST"]
LEDGER_URI = "/api/v1/events"
LEDGER_TOKEN = ENV.fetch("LEDGER_TOKEN", false)

class LedgerClient
  def connection
    @client ||= Faraday.new(url: "http://" + LEDGER_HOST + LEDGER_URI)
  end

  def deployment(deploy)
    event = {
      id:           deploy.id,
      name:         deploy.project.name,
      actor:        deploy.user.name,
      status:       deploy.status,
      started_at:   deploy.created_at.iso8601,
      summary:      deploy.summary,
      environment:  deploy.stage.deploy_groups.map(&:environment).uniq.map(&:name).join("'"),
      url:          deploy.url,
      pods:         deploy.stage.deploy_groups.map(&:permalink)
    }
    create_event(event)
  end

  def create_event(event)
    events = { "events": [event] }
    results = post(events)
    # TODO: raise or display errors if results.status != 200
    results
  end

  def self.post_deployment(deploy)
    lc = LedgerClient.new
    lc.deployment(deploy)
  end

  private

  def post(data)
    connection.post do |request|
      request.headers['Content-Type'] = "application/json"
      request.headers['Authorization'] = "Token token=#{LEDGER_TOKEN}"
      request.body = data.to_json
    end
  end
end
