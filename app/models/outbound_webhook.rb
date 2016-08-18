# frozen_string_literal: true

require 'faraday'

class OutboundWebhook < ActiveRecord::Base
  has_soft_deletion default_scope: true

  belongs_to :project
  belongs_to :stage

  validates :url, uniqueness: {
    scope: [:stage],
    conditions: -> { where("deleted_at IS NULL") },
    message: "one webhook per (stage, url) combination."
  }
  validate :url_is_not_relative
  validates_presence_of :username, if: proc { |outbound_webhook| outbound_webhook.password.present? }

  def deliver(deploy)
    Rails.logger.info "Sending webhook notification to #{self.url}. Deploy: #{deploy.id}"

    response = connection.post do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = DeployPresenter.new(deploy).present.to_json
    end

    if response.success?
      Rails.logger.info "Webhook notification sent. Deploy: #{deploy.id}"
    else
      Rails.logger.error "Failed to send webhook notification. Deploy: #{deploy.id} Response: #{response.inspect}"
    end

    response.success?
  end

  def connection
    Faraday.new(url: self.url) do |faraday|
      faraday.request  :url_encoded
      faraday.response :logger
      faraday.adapter  Faraday.default_adapter
      faraday.basic_auth(self.username, self.password) if self.username.present?
    end
  end

  private

  def url_is_not_relative
    errors.add(:url, "must begin with http:// or https://") unless self.url.start_with?("http://", "https://")
  end
end
