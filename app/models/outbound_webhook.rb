# frozen_string_literal: true

require 'faraday'

class OutboundWebhook < ActiveRecord::Base
  AUTH_TYPES = ["None", "Basic", "Token", "Bearer"].freeze

  audited

  has_many :outbound_webhook_stages, dependent: nil, inverse_of: :outbound_webhook
  has_many :stages, through: :outbound_webhook_stages, dependent: nil, inverse_of: :outbound_webhooks

  validate :validate_url_is_absolute
  validate :validate_auth

  before_destroy :ensure_unused

  def deliver(deploy, output)
    prefix = "Webhook notification:"
    output.puts "#{prefix} sending to #{url} ..."

    error_message =
      begin
        response = connection.post url do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = self.class.deploy_as_json(deploy).to_json
        end

        if response.success?
          output.puts "#{prefix} succeeded"
          return
        else
          Rails.logger.error "Outbound Webhook Error #{id} #{url} #{response.body}"
          "#{prefix} failed #{response.status}\n#{response.body.to_s.truncate(100)}"
        end
      rescue StandardError => e # Timeout or SSL error
        "#{prefix} failed #{e.class}"
      end

    raise Samson::Hooks::UserError, error_message
  end

  def self.deploy_as_json(deploy)
    deploy.as_json.merge(
      "project" => deploy.project.as_json,
      "stage" => deploy.stage.as_json,
      "user" => deploy.user.as_json
    )
  end

  def ssl?
    url.start_with?("https://") && !insecure?
  end

  def as_json(*)
    super(except: [:password])
  end

  private

  def connection
    Faraday.new(ssl: {verify: !insecure}) do |connection|
      connection.request  :url_encoded
      connection.adapter  Faraday.default_adapter

      case auth_type
      when "None" # rubocop:disable Lint/EmptyWhen noop
      when "Basic" then connection.basic_auth(username, password)
      when "Bearer", "Token" then connection.authorization auth_type, password
      else raise ArgumentError, "Unsupported auth_type #{auth_type.inspect}"
      end
    end
  end

  def validate_auth
    case auth_type
    when "None" # rubocop:disable Lint/EmptyWhen noop
    when "Basic" then errors.add :username, "and password must be set" if !username? || !password?
    when "Bearer", "Token" then errors.add :password, "must be set" unless password?
    else errors.add(:auth_type, "unknown, supported types are #{AUTH_TYPES.to_sentence}")
    end
  end

  def validate_url_is_absolute
    errors.add(:url, "must begin with http:// or https://") unless url.start_with?("http://", "https://")
  end

  def ensure_unused
    return if outbound_webhook_stages.empty?
    errors.add :base, 'Can only delete when unused.'
    throw :abort
  end
end
Samson::Hooks.load_decorators(OutboundWebhook)
